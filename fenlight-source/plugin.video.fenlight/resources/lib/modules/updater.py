# -*- coding: utf-8 -*-
from modules import kodi_utils

_DISABLED_MESSAGE = 'Fen Light updates are managed by KodiPortable Install.bat'

def _disabled():
	return kodi_utils.notification(_DISABLED_MESSAGE, time=5000)

def get_location(insert=''):
	return ''

def get_versions():
	return None, None

def get_changes(online_version=None):
	return _disabled()

def version_check(current_version, online_version):
	return False

def update_check(action=4):
	if action == 3: return
	return _disabled()

def rollback_check():
	return _disabled()

def update_addon(new_version, action, show_after_action=True):
	return _disabled()
