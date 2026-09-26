# -*- coding: utf-8 -*-
"""
    Rutor source adapted to the CocoScrapers source contract.

    Rutor currently exposes ordinary HTML search results.  This module keeps
    the provider self-contained and returns only torrent magnets; it does not
    use any debrid service API.
"""

import html
import re
from urllib.parse import parse_qs, quote_plus, unquote_plus, urlparse

import requests

from cocoscrapers.modules import log_utils
from cocoscrapers.modules import source_utils


class source:
    priority = 3
    pack_capable = True
    hasMovies = True
    hasEpisodes = True

    def __init__(self):
        self.language = ['en']
        self.base_link = 'https://rutor.info'
        self.search_link = '/search/0/0/000/2/%s'
        self.headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        self.timeout = 10
        self.min_seeders = 0

    def _request(self, query):
        try:
            url = '%s%s' % (self.base_link, self.search_link % quote_plus(query))
            response = requests.get(url, headers=self.headers, timeout=self.timeout)
            if response.status_code != 200:
                log_utils.log('[RUTOR] HTTP %s' % response.status_code)
                return ''
            return response.text
        except Exception as e:
            log_utils.log('[RUTOR] request failed: %s' % e)
            return ''

    def _rows(self, response):
        return re.findall(r'(?is)<tr\b[^>]*>.*?</tr>', response or '')

    def _query_variants(self, query):
        query = re.sub(r'\s+', ' ', query or '').strip()
        variants = [query]
        words = re.findall(r'[A-Za-z0-9][A-Za-z0-9.-]{2,}', query)
        words = [
            word for word in words
            if not re.match(r'(?i)^(?:s\d{1,2}e\d{1,2}|season|complete|\d{4})$', word)
        ]
        if words:
            variants.append(max(words, key=len))
        return list(dict.fromkeys(i for i in variants if i))

    def _records(self, queries):
        records = []
        seen = set()
        for query in queries:
            for variant in self._query_variants(query):
                for row in self._rows(self._request(variant)):
                    record = self._record(row)
                    if record and record['hash'] not in seen:
                        seen.add(record['hash'])
                        records.append(record)
        return records

    def _clean_html(self, value):
        value = re.sub(r'(?is)<[^>]+>', ' ', value or '')
        return re.sub(r'\s+', ' ', html.unescape(value)).strip()

    def _size(self, row):
        match = re.search(
            r'(\d+(?:[.,]\d+)?)\s*(TB|GB|MB|KB|TiB|GiB|MiB|KiB)',
            html.unescape(row or ''), re.I
        )
        if not match:
            return 0, ''
        number = match.group(1)
        if ',' in number and '.' not in number:
            number = number.replace(',', '.')
        else:
            number = number.replace(',', '')
        try:
            value = float(number)
        except Exception:
            return 0, ''
        unit = match.group(2).lower()
        factors = {
            'tb': 1024.0, 'tib': 1024.0,
            'gb': 1.0, 'gib': 1.0,
            'mb': 1.0 / 1024.0, 'mib': 1.0 / 1024.0,
            'kb': 1.0 / 1048576.0, 'kib': 1.0 / 1048576.0,
        }
        value *= factors.get(unit, 0)
        return round(value, 2), '%.2f GB' % value

    def _record(self, row):
        match = re.search(r'href\s*=\s*["\'](magnet:\?[^"\']+)', row, re.I)
        if not match:
            return None
        magnet = unquote_plus(html.unescape(match.group(1)))
        hash_match = re.search(r'btih:([^&]+)', magnet, re.I)
        if not hash_match:
            return None
        info_hash = hash_match.group(1).strip()
        if len(info_hash) == 32:
            try:
                info_hash = source_utils.base32_to_hex(info_hash, 'RUTOR')
            except Exception:
                return None
        if not re.match(r'^[0-9a-f]{40}$', info_hash, re.I):
            return None

        title_match = re.search(
            r'<a[^>]+href=["\']/torrent/[^"\']+["\'][^>]*>(.*?)</a>',
            row, re.I | re.S
        )
        name = self._clean_html(title_match.group(1)) if title_match else ''
        if not name:
            try:
                name = parse_qs(urlparse(magnet).query).get('dn', [''])[0]
            except Exception:
                name = ''
        name = source_utils.clean_name(name)
        if not name:
            return None

        seed_match = re.search(
            r'class=["\']green["\'][^>]*>.*?(\d[\d\s,]*)</span>',
            row, re.I | re.S
        )
        try:
            seeders = int(re.sub(r'\D', '', seed_match.group(1))) if seed_match else 0
        except Exception:
            seeders = 0
        size, size_text = self._size(row)
        return {
            'hash': info_hash.upper(),
            'name': name,
            'seeders': seeders,
            'size': size,
            'size_text': size_text,
        }

    def _make_item(self, record, title, aliases, year, hdlr, episode_title,
                   years=None, package=None, search_series=False,
                   total_seasons=None, bypass_filter=False, imdb=None):
        name = record['name']
        if package:
            episode_start, episode_end = 0, 0
            if not bypass_filter:
                if search_series:
                    valid, last_season = source_utils.filter_show_pack(
                        title, aliases, imdb or '', year, hdlr, name, total_seasons
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
            package_name = 'show' if search_series else 'season'
            name_info = source_utils.info_from_name(
                name, title, year, season=hdlr, pack=package_name
            )
        else:
            if not source_utils.check_title(title, aliases, name, hdlr, year, years):
                return None
            if years and re.search(r'(?i)(?:s\d{1,2}e\d{1,2}|season[ ._-]?\d+)', name):
                return None
            name_info = source_utils.info_from_name(name, title, year, hdlr, episode_title)

        if source_utils.remove_lang(name_info, source_utils.check_foreign_audio()):
            return None
        undesirables = source_utils.get_undesirables()
        if undesirables and source_utils.remove_undesirables(name_info, undesirables):
            return None
        if record['seeders'] < self.min_seeders:
            return None

        magnet = 'magnet:?xt=urn:btih:%s&dn=%s' % (record['hash'], quote_plus(name))
        quality, info = source_utils.get_release_quality(name_info, magnet)
        if record['size_text']:
            info.insert(0, record['size_text'])
        result = {
            'provider': 'rutor',
            'source': 'torrent',
            'seeders': record['seeders'],
            'hash': record['hash'],
            'name': name,
            'name_info': name_info,
            'quality': quality,
            'language': 'en',
            'url': magnet,
            'info': ' | '.join(info),
            'direct': False,
            'debridonly': True,
            'size': record['size'],
        }
        if package:
            result['package'] = package_name
            if search_series:
                result['last_season'] = last_season
            elif episode_start:
                result['episode_start'] = episode_start
                result['episode_end'] = episode_end
        return result

    def _regular(self, data):
        if 'tvshowtitle' in data:
            title = data['tvshowtitle']
            hdlr = 'S%02dE%02d' % (int(data['season']), int(data['episode']))
            episode_title = data.get('title')
            years = None
        else:
            title = data['title']
            year = str(data['year'])
            hdlr = year
            episode_title = None
            years = [str(int(year) - 1), year, str(int(year) + 1)]
        title = title.replace('&', 'and').replace('/', ' ').replace('$', 's')
        year = str(data['year'])
        query = '%s %s' % (re.sub(r'[^A-Za-z0-9\s\.-]+', '', title), hdlr)
        results = []
        for record in self._records([query]):
            try:
                item = self._make_item(
                    record, title, data.get('aliases', []), year, hdlr,
                    episode_title, years=years
                )
                if item:
                    results.append(item)
            except Exception:
                source_utils.scraper_error('RUTOR')
        return results

    def sources(self, data, hostDict):
        if not data:
            return []
        try:
            return self._regular(data)
        except Exception:
            source_utils.scraper_error('RUTOR')
            return []

    def sources_packs(self, data, hostDict, search_series=False,
                      total_seasons=None, bypass_filter=False):
        if not data:
            return []
        try:
            title = data['tvshowtitle'].replace('&', 'and').replace('/', ' ').replace('$', 's')
            title = re.sub(r'[^A-Za-z0-9\s\.-]+', '', title)
            season = str(data['season'])
            season_xx = season.zfill(2)
            if search_series:
                queries = ['%s Season' % title, '%s Complete' % title]
            else:
                queries = ['%s S%s' % (title, season_xx), '%s Season %s' % (title, season)]

            records = self._records(queries)

            results = []
            for record in records:
                try:
                    item = self._make_item(
                        record, data['tvshowtitle'], data.get('aliases', []),
                        str(data['year']), season, None,
                        package='show' if search_series else 'season',
                        search_series=search_series, total_seasons=total_seasons,
                        bypass_filter=bypass_filter, imdb=data.get('imdb')
                    )
                    if item:
                        results.append(item)
                except Exception:
                    source_utils.scraper_error('RUTOR')
            return results
        except Exception:
            source_utils.scraper_error('RUTOR')
            return []
