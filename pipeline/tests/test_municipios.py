"""Testes da população municipal (anos sem fonte e escolha das fontes).

Rodar, de dentro de pipeline/:  python -m unittest discover tests   (ou pytest tests)
"""

from __future__ import annotations

import unittest

from vigitrop_pipeline.municipios import CENSOS, ESTIMATIVAS, completar_anos, fontes_por_ano


class TestFontes(unittest.TestCase):
    def test_ancoras_sao_contagens_e_estimativas_pos_censo(self):
        estimativas = set(range(2001, 2022)) | {2024, 2025}
        ancoras, reserva = fontes_por_ano(range(2007, 2027), estimativas)
        self.assertEqual(sorted(ancoras), [2007, 2010, 2022, 2024, 2025])
        self.assertEqual(ancoras[2010], CENSOS[2010])
        self.assertEqual(ancoras[2024], ESTIMATIVAS)
        # Estimativas antigas só como reserva; 2023 e 2026 não têm fonte nenhuma
        self.assertEqual(sorted(reserva), [2008, 2009, *range(2011, 2022)])


class TestCompletarAnos(unittest.TestCase):
    def test_interpola_entre_ancoras(self):
        ancoras = {2010: {"A": 100.0, "B": 50.0}, 2014: {"A": 140.0, "B": 10.0}}
        r = completar_anos(ancoras, range(2010, 2015))
        self.assertAlmostEqual(r[2011]["A"], 110.0)
        self.assertAlmostEqual(r[2013]["B"], 20.0)
        self.assertEqual(r[2014], ancoras[2014])

    def test_repete_a_ultima_e_a_primeira(self):
        ancoras = {2010: {"A": 100.0}, 2012: {"A": 120.0}}
        r = completar_anos(ancoras, range(2008, 2015))
        self.assertEqual(r[2008], {"A": 100.0})
        self.assertEqual(r[2014], {"A": 120.0})

    def test_municipio_novo_vem_da_reserva(self):
        # "N" foi criado depois de 2010: não está na primeira âncora
        ancoras = {2010: {"A": 100.0}, 2014: {"A": 80.0, "N": 30.0}}
        reserva = {2012: {"A": 999.0, "N": 25.0}}
        r = completar_anos(ancoras, range(2010, 2015), reserva)
        self.assertAlmostEqual(r[2012]["A"], 90.0)  # interpolado, não a reserva
        self.assertAlmostEqual(r[2012]["N"], 25.0)
        self.assertNotIn("N", r[2011])  # sem reserva no ano: fica de fora

    def test_sem_ancora(self):
        with self.assertRaises(ValueError):
            completar_anos({}, range(2010, 2012))


if __name__ == "__main__":
    unittest.main()
