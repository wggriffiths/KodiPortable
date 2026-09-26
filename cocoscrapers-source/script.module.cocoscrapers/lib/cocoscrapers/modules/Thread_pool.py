"""Bounded daemon workers used by CocoScrapers providers.

Kodi waits for every Python thread state in an add-on interpreter when a
script finishes. ``ThreadPoolExecutor`` keeps non-daemon workers alive for
reuse, so a finished scrape can keep Kodi waiting during shutdown. These
workers are daemon threads and are torn down with each batch.
"""

from queue import Empty, Queue
from cocoscrapers.modules.workers import Thread

MAX_WORKERS = 10

def _run_jobs(func, jobs):
	jobs = list(jobs)
	if not jobs: return

	queue = Queue()
	for args in jobs: queue.put(args)

	def worker():
		while True:
			try: args = queue.get_nowait()
			except Empty: return
			try: func(*args)
			except: pass
			finally: queue.task_done()

	threads = [Thread(worker) for _ in range(min(MAX_WORKERS, len(jobs)))]
	for thread in threads: thread.start()
	for thread in threads: thread.join()

def run_and_wait(func, iterable):
	_run_jobs(func, ((item,) for item in iterable))

def run_and_wait_multi(func, iterable):
	_run_jobs(func, iterable)

def shutdown_executor():
	# Kept for service.py compatibility. Workers are batch-scoped and have
	# already finished before provider or Kodi shutdown reaches here.
	return
