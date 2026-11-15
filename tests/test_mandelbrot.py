import unittest

from tests._worker import worker

BASE = {"width": 60, "height": 40, "max_iter": 50}


class TestMandelbrot(unittest.TestCase):
    def strip(self, a, b):
        return worker.mandelbrot({**BASE, "row_start": a, "row_end": b})

    def test_deterministik(self):
        self.assertEqual(self.strip(0, 40), self.strip(0, 40))

    def test_potongan_dijumlah_sama_dengan_utuh(self):
        # Inti pembagian tugas: hasil per strip (tiap compute node) dijumlah = hasil sekaligus
        full = self.strip(0, 40)
        parts = [self.strip(0, 13), self.strip(13, 27), self.strip(27, 40)]
        self.assertEqual(sum(p["inside"] for p in parts), full["inside"])
        self.assertEqual(sum(p["iter_sum"] for p in parts), full["iter_sum"])

    def test_ada_titik_di_dalam_himpunan(self):
        r = self.strip(0, 40)
        self.assertGreater(r["inside"], 0)
        self.assertLessEqual(r["inside"], 60 * 40)

    def test_strip_kosong(self):
        self.assertEqual(self.strip(5, 5), {"inside": 0, "iter_sum": 0})


if __name__ == "__main__":
    unittest.main()
