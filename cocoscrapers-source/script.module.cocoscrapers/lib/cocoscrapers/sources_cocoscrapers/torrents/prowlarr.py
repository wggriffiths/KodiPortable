# -*- coding: utf-8 -*-
"""
    Prowlarr source for CocoScrapers.

    Prowlarr is a self-hosted indexer gateway.  It is deliberately disabled by
    default and only returns torrent results that contain a usable info hash.
"""

import re
from urllib.parse import quote_plus

import requests

from cocoscrapers.modules import log_utils
from cocoscrapers.modules import source_utils
from cocoscrapers.modules.control import setting as getSetting


class source:
    priority = 1
    pack_capable = True
    hasMovies = True
    hasEpisodes = True

    def __init__(self):
        self.language = ['en']
        self.token = (getSetting('prowlarr.token') or '').strip()
        self.base_link = (getSetting('prowlarr.url') or '').strip().rstrip('/')
        self.headers = {'user-agent': 'CocoScrapers', 'x-api-key': self.token}
        self.timeout = 10
        self.min_seeders = 0

    def _search(self, query, category):
        if not self.token or not self.base_link or not query:
            return []
        try:
            response = requests.get(
                '%s/api/v1/search' % self.base_link,
                params={
                    'type': 'search',
                    'limit': 100,
                    'categories': category,
                    'query': query,
                },
                headers=self.headers,
                timeout=self.timeout,
            )
            if response.status_code != 200:
                log_utils.log('[PROWLARR] HTTP %s' % response.status_code)
                return []
            results = response.json()
            if isinstance(results, dict):
                results = results.get('results', [])
            return results if isinstance(results, list) else []
        except Exception as e:
            log_utils.log('[PROWLARR] search failed: %s' % e)
            return []

    def _hash_from_file(self, item):
        info_hash = item.get('infoHash') or ''
        if not info_hash:
            magnet = item.get('magnetUrl') or item.get('magnetUri') or ''
            match = re.search(r'btih:([^&]+)', magnet, re.I)
            if match:
                info_hash = match.group(1)
        info_hash = str(info_hash).strip()
        if len(info_hash) == 32:
            try:
                info_hash = source_utils.base32_to_hex(info_hash, 'PROWLARR')
            except Exception:
                return None
        if not re.match(r'^[0-9a-f]{40}$', info_hash, re.I):
            return None
        return info_hash.upper()

    def _size(self, item):
        try:
            size = float(item.get('size') or 0)
            if size <= 0:
                return 0, ''
            return source_utils.convert_size(size, 'GB')
        except Exception:
            return 0, ''

    def _make_item(self, item, title, aliases, year, hdlr, episode_title,
                   years=None, package=None, search_series=False,
                   total_seasons=None, bypass_filter=False, imdb=None):
        if str(item.get('protocol', '')).lower() != 'torrent':
            return None

        name = source_utils.clean_name(item.get('title') or '')
        if not name:
            return None

        if package:
            if not bypass_filter:
                if search_series:
                    valid, last_season = source_utils.filter_show_pack(
                        title, aliases, imdb or '', year, hdlr,
                        name, total_seasons
                    )
                    if not valid:
                        return None
                else:
                    valid, episode_start, episode_end = source_utils.filter_season_pack(
                        title, aliases, year, hdlr, name
                    )
                    if not valid:
                        return None
            else:
                last_season = total_seasons
                episode_start, episode_end = 0, 0
        else:
            if not source_utils.check_title(title, aliases, name, hdlr, year, years):
                return None
            if years and re.search(r'(?i)(?:s\d{1,2}e\d{1,2}|season[ ._-]?\d+)', name):
                return None

        info_hash = self._hash_from_file(item)
        if not info_hash:
            return None
        magnet = item.get('magnetUrl') or item.get('magnetUri') or ''
        if not str(magnet).lower().startswith('magnet:'):
            magnet = 'magnet:?xt=urn:btih:%s&dn=%s' % (info_hash, quote_plus(name))

        if package:
            name_info = source_utils.info_from_name(
                name, title, year, season=hdlr, pack=package
            )
        else:
            name_info = source_utils.info_from_name(
                name, title, year, hdlr, episode_title
            )
        if source_utils.remove_lang(name_info, source_utils.check_foreign_audio()):
            return None
        undesirables = source_utils.get_undesirables()
        if undesirables and source_utils.remove_undesirables(name_info, undesirables):
            return None

        try:
            seeders = int(item.get('seeders') or 0)
        except Exception:
            seeders = 0
        if seeders < self.min_seeders:
            return None

        quality, info = source_utils.get_release_quality(name_info, magnet)
        dsize, isize = self._size(item)
        if isize:
            info.insert(0, isize)
        result = {
            'provider': item.get('indexer') or 'prowlarr',
            'source': 'torrent',
            'seeders': seeders,
            'hash': info_hash,
            'name': name,
            'name_info': name_info,
            'quality': quality,
            'language': 'en',
            'url': magnet,
            'info': ' | '.join(info),
            'direct': False,
            'debridonly': True,
            'size': dsize,
        }
        if package:
            result['package'] = package
            if search_series:
                result['last_season'] = last_season
            elif episode_start:
                result['episode_start'] = episode_start
                result['episode_end'] = episode_end
        return result

    def sources(self, data, hostDict):
        sources = []
        if not data or not self.token or not self.base_link:
            return sources
        try:
            title = data['tvshowtitle'] if 'tvshowtitle' in data else data['title']
            title = title.replace('&', 'and').replace('/', ' ').replace('$', 's')
            aliases = data.get('aliases', [])
            year = str(data.get('year') or '')
            if 'tvshowtitle' in data:
                hdlr = 'S%02dE%02d' % (int(data['season']), int(data['episode']))
                query = '%s %s' % (title, hdlr)
                years = None
                episode_title = data.get('title')
                category = 5000
            else:
                hdlr = year
                years = [str(int(year) - 1), year, str(int(year) + 1)] if year else None
                query = '%s %s' % (title, year) if year else title
                episode_title = None
                category = 2000
            files = self._search(query, category)
            for item in files:
                result = self._make_item(
                    item, title, aliases, year, hdlr, episode_title, years=years
                )
                if result:
                    sources.append(result)
        except Exception:
            source_utils.scraper_error('PROWLARR')
        return sources

    def sources_packs(self, data, hostDict, search_series=False,
                      total_seasons=None, bypass_filter=False):
        sources = []
        if not data or not self.token or not self.base_link:
            return sources
        try:
            title = data['tvshowtitle'].replace('&', 'and').replace('/', ' ').replace('$', 's')
            aliases = data.get('aliases', [])
            year = str(data.get('year') or '')
            season = str(data['season'])
            season_xx = season.zfill(2)
            if search_series:
                queries = ['%s Season' % title, '%s Complete' % title]
            else:
                queries = ['%s S%s' % (title, season_xx), '%s Season %s' % (title, season)]

            files = []
            seen = set()
            for query in queries:
                for item in self._search(query, 5000):
                    key = item.get('infoHash') or item.get('title')
                    if key in seen:
                        continue
                    seen.add(key)
                    files.append(item)

            for item in files:
                result = self._make_item(
                    item, title, aliases, year, season, None,
                    package='show' if search_series else 'season',
                    search_series=search_series,
                    total_seasons=total_seasons,
                    bypass_filter=bypass_filter,
                    imdb=data.get('imdb'),
                )
                if result:
                    sources.append(result)
        except Exception:
            source_utils.scraper_error('PROWLARR')
        return sources
