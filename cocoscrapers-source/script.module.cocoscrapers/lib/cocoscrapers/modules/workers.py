# -*- coding: utf-8 -*-
"""
	Fenomscrapers Module
"""

from threading import Thread as thread

class Thread(thread):
	def __init__(self, target, *args):
		self._worker_target = target
		self._worker_args = args
		self._language_source_utils = None
		self._preferred_language = ''
		try:
			from cocoscrapers.modules import source_utils
			self._language_source_utils = source_utils
			self._preferred_language = source_utils.get_preferred_language_context()
		except: pass
		thread.__init__(self, target=self._run_with_language_context, daemon=True)

	def _run_with_language_context(self):
		context_set = False
		try:
			if self._language_source_utils and self._preferred_language:
				try:
					self._language_source_utils.set_preferred_language(self._preferred_language)
					context_set = True
				except: pass
			return self._worker_target(*self._worker_args)
		finally:
			if context_set:
				try: self._language_source_utils.clear_preferred_language()
				except: pass
			self._worker_target, self._worker_args = None, ()
			self._preferred_language, self._language_source_utils = '', None
