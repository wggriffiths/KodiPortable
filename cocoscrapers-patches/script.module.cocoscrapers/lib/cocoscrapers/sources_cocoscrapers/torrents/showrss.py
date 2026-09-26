# -*- coding: utf-8 -*-
"""
    showRSS episode source adapted to CocoScrapers.

    showRSS publishes episode magnets through RSS feeds.  It is episode-only
    and intentionally does not advertise pack support.
"""

import html
import re
import threading
from urllib.parse import unquote_plus

import requests

from cocoscrapers.modules import log_utils
from cocoscrapers.modules import source_utils


class source:
    priority = 4
    pack_capable = False
    hasMovies = False
    hasEpisodes = True
    _show_list = None
    _show_lock = threading.Lock()

    def __init__(self):
        self.language = ['en']
        self.base_link = 'https://showrss.info'
        self.headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        self.timeout = 15

    @staticmethod
    def _key(value):
        return re.sub(r'[^a-z0-9]+', '', (value or '').lower())

    def _get_show_list(self):
        if source._show_list is not None:
            return source._show_list
        with source._show_lock:
            if source._show_list is not None:
                return source._show_list
            try:
                response = requests.get(
                    '%s/browse' % self.base_link,
                    headers=self.headers,
                    timeout=self.timeout,
                )
                if response.status_code != 200:
                    return []
                shows = []
                for match in re.finditer(
                    r'<option[^>]+value=["\']([^"\']+)["\'][^>]*>(.*?)</option>',
                    response.text, re.I | re.S
                ):
                    show_id = match.group(1)
                    show_title = re.sub(r'\s+', ' ', html.unescape(match.group(2))).strip()
                    if show_id != 'all' and show_title:
                        shows.append((self._key(show_title), show_id))
                source._show_list = shows
                return shows
            except Exception as e:
                log_utils.log('[SHOWRSS] show list failed: %s' % e)
                return []

    def _find_show_id(self, title, aliases):
        shows = self._get_show_list()
        candidates = [title] + [i for i in aliases if isinstance(i, str)]
        candidates = [self._key(i) for i in candidates if self._key(i)]
        for candidate in candidates:
            for show_title, show_id in shows:
                if show_title == candidate or show_title.startswith(candidate):
                    return show_id
        return None

    def _feed(self, show_id):
        try:
            response = requests.get(
                '%s/show/%s.rss' % (self.base_link, show_id),
                headers=self.headers,
                timeout=self.timeout,
            )
            if response.status_code != 200:
                return ''
            return response.text
        except Exception as e:
            log_utils.log('[SHOWRSS] feed failed: %s' % e)
            return ''

    def sources(self, data, hostDict):
        if not data or 'tvshowtitle' not in data:
            return []
        try:
            title = data['tvshowtitle'].replace('&', 'and').replace('/', ' ').replace('$', 's')
            year = str(data['year'])
            hdlr = 'S%02dE%02d' % (int(data['season']), int(data['episode']))
            show_id = self._find_show_id(title, data.get('aliases', []))
            if not show_id:
                return []
            feed = self._feed(show_id)
            if not feed:
                return []

            results = []
            undesirables = source_utils.get_undesirables()
            foreign_audio = source_utils.check_foreign_audio()
            items = re.findall(r'(?is)<item\b.*?</item>', feed)
            for item in items:
                raw_match = re.search(r'(?is)<tv:raw_title>(.*?)</tv:raw_title>', item)
                if not raw_match:
                    raw_match = re.search(r'(?is)<title>(.*?)</title>', item)
                magnet_match = re.search(r'(?is)<link>\s*(magnet:\?.*?)\s*</link>', item)
                if not raw_match or not magnet_match:
                    continue
                name = source_utils.clean_name(html.unescape(raw_match.group(1)))
                magnet = unquote_plus(html.unescape(magnet_match.group(1)))
                hash_match = re.search(r'btih:([^&]+)', magnet, re.I)
                if not hash_match:
                    continue
                info_hash = hash_match.group(1).upper()
                if len(info_hash) == 32:
                    try:
                        info_hash = source_utils.base32_to_hex(info_hash, 'SHOWRSS').upper()
                    except Exception:
                        continue
                if not re.match(r'^[0-9A-F]{40}$', info_hash):
                    continue
                if not source_utils.check_title(title, data.get('aliases', []), name, hdlr, year):
                    continue
                name_info = source_utils.info_from_name(
                    name, title, year, hdlr, data.get('title')
                )
                if source_utils.remove_lang(name_info, foreign_audio):
                    continue
                if undesirables and source_utils.remove_undesirables(name_info, undesirables):
                    continue
                quality, info = source_utils.get_release_quality(name_info, magnet)
                results.append({
                    'provider': 'showrss',
                    'source': 'torrent',
                    'seeders': 0,
                    'hash': info_hash,
                    'name': name,
                    'name_info': name_info,
                    'quality': quality,
                    'language': 'en',
                    'url': magnet,
                    'info': ' | '.join(info),
                    'direct': False,
                    'debridonly': True,
                    'size': 0,
                })
            return results
        except Exception:
            source_utils.scraper_error('SHOWRSS')
            return []
