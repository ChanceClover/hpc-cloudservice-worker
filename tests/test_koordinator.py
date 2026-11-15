import json
import unittest
from unittest import mock

from tests._worker import worker


class FakeResp:
    def __init__(self, body, status=200):
        self.status, self._body = status, body

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class TestKoordinator(unittest.TestCase):
    def test_call_kirim_bearer_dan_json(self):
        with mock.patch("urllib.request.urlopen", return_value=FakeResp(b'{"worker_id": "w1"}')) as op:
            out = worker.call("/api/register", {"name": "x"})
        req = op.call_args[0][0]
        self.assertEqual(out, {"worker_id": "w1"})
        self.assertEqual(req.get_header("Authorization"), "Bearer " + worker.TOKEN)
        self.assertEqual(json.loads(req.data), {"name": "x"})
        self.assertTrue(req.full_url.endswith("/api/register"))

    def test_call_204_none(self):
        with mock.patch("urllib.request.urlopen", return_value=FakeResp(b"", 204)):
            self.assertIsNone(worker.call("/api/tasks/claim", {"worker_id": "w1"}))

    def test_register_kembalikan_worker_id(self):
        with mock.patch.object(worker, "call", return_value={"worker_id": "abc"}) as c:
            self.assertEqual(worker.register(), "abc")
        c.assert_called_once_with("/api/register", {"name": worker.NAME})

    def test_jenis_tugas_terdaftar(self):
        self.assertEqual(set(worker.KINDS), {"montecarlo_pi", "mandelbrot"})


if __name__ == "__main__":
    unittest.main()
