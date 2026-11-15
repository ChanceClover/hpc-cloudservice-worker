import unittest

from tests._worker import worker


class TestMonteCarloPi(unittest.TestCase):
    def test_deterministik_per_seed(self):
        p = {"seed": 42, "samples": 20000}
        self.assertEqual(worker.montecarlo_pi(p), worker.montecarlo_pi(p))

    def test_seed_beda_hasil_beda(self):
        a = worker.montecarlo_pi({"seed": 1, "samples": 20000})
        b = worker.montecarlo_pi({"seed": 2, "samples": 20000})
        self.assertNotEqual(a, b)

    def test_rentang_dan_perkiraan_pi(self):
        n = 200000
        inside = worker.montecarlo_pi({"seed": 7, "samples": n})["inside"]
        self.assertTrue(0 <= inside <= n)
        self.assertAlmostEqual(4 * inside / n, 3.14159, delta=0.02)

    def test_nol_sampel(self):
        self.assertEqual(worker.montecarlo_pi({"seed": 1, "samples": 0}), {"inside": 0})


if __name__ == "__main__":
    unittest.main()
