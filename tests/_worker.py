"""Impor worker.py tanpa koordinator sungguhan (worker membaca env saat diimpor)."""
import os

os.environ.setdefault("COORDINATOR_URL", "http://koordinator.test")
os.environ.setdefault("WORKER_TOKEN", "token-uji")
os.environ.setdefault("WORKER_NAME", "uji")

import worker  # noqa: E402,F401
