"""Testes do ajuste de tendência (joinpoint) com séries sintéticas de tendência conhecida.

Rodar, de dentro de pipeline/:  python -m unittest discover tests   (ou pytest tests)
"""

from __future__ import annotations

import math
import random
import unittest

from vigitrop_pipeline.tendencia import (
    MEIO_CASO,
    ajustar,
    candidatos,
    max_joinpoints,
    quantil_t,
    serie_taxas,
)


def serie(anos: list[int], apcs: list[float], joinpoints: list[int], taxa0: float = 50.0,
          ruido: float = 0.0, semente: int = 1) -> list[float]:
    """Taxas com APC conhecido em cada segmento e ruído multiplicativo log-normal (desvio `ruido` no log)."""
    rnd = random.Random(semente)
    limites = [anos[0], *joinpoints]
    taxas = []
    for ano in anos:
        ln = math.log(taxa0)
        for j, apc in enumerate(apcs):
            ini = limites[j]
            fim = limites[j + 1] if j + 1 < len(limites) else ano
            ln += math.log1p(apc / 100) * max(0, min(ano, fim) - ini)
        taxas.append(math.exp(ln + rnd.gauss(0, ruido)))
    return taxas


class TestQuantilT(unittest.TestCase):
    def test_tabela(self):
        # t de Student, 97,5% (tabela padrão)
        for gl, esperado in [(1, 12.706205), (2, 4.302653), (5, 2.570582), (10, 2.228139), (30, 2.042272)]:
            self.assertAlmostEqual(quantil_t(0.975, gl), esperado, places=5)

    def test_outros_quantis(self):
        self.assertAlmostEqual(quantil_t(0.95, 8), 1.859548, places=5)
        self.assertAlmostEqual(quantil_t(0.995, 3), 5.840909, places=5)


class TestRegrasJoinpoint(unittest.TestCase):
    def test_max_joinpoints(self):
        self.assertEqual([max_joinpoints(n) for n in (5, 7, 11, 12, 16, 17, 21, 30)], [0, 1, 1, 2, 2, 3, 3, 3])

    def test_minimo_de_observacoes(self):
        n = 12
        for k in (1, 2, 3):
            for idx in candidatos(n, k):
                self.assertGreaterEqual(idx[0], 2)  # 2 observações antes do 1º joinpoint
                self.assertLessEqual(idx[-1], n - 3)  # 2 depois do último
                for a, b in zip(idx, idx[1:]):
                    self.assertGreaterEqual(b - a - 1, 2)  # 2 entre joinpoints
        self.assertEqual(list(candidatos(5, 1)), [(2,)])
        self.assertEqual(list(candidatos(7, 2)), [])


class TestAjuste(unittest.TestCase):
    def test_sem_quebra(self):
        anos = list(range(2005, 2025))
        aj = ajustar(anos, serie(anos, [-3.0], [], ruido=0.02), k_max=0)
        (seg,) = aj.segmentos
        self.assertAlmostEqual(seg.apc, -3.0, delta=0.5)
        self.assertTrue(seg.ic_inf < -3.0 < seg.ic_sup)
        self.assertTrue(seg.significativo)
        self.assertAlmostEqual(aj.aapc.apc, seg.apc, places=10)
        self.assertAlmostEqual(aj.aapc.ic_inf, seg.ic_inf, places=10)  # um segmento: AAPC = APC, mesmo IC

    def test_cobertura_ic(self):
        # Sem quebra, k fixo em 0 e sem a correção de autocorrelação (erros independentes, como
        # aqui), o IC95% (t de Student) deve cobrir o APC verdadeiro ~95% das vezes.
        anos = list(range(2007, 2023))
        cobre = sum(seg.ic_inf < 4.0 < seg.ic_sup
                    for s in range(400)
                    for seg in ajustar(anos, serie(anos, [4.0], [], ruido=0.1, semente=s), k_max=0,
                                       autocorrelacao=False).segmentos)
        self.assertTrue(0.92 <= cobre / 400 <= 0.98, cobre)

    def test_falso_joinpoint(self):
        # Sem quebra, o BIC escolhe 0 joinpoints na maioria das séries. Não é 100%: a busca pela
        # posição favorece achar uma quebra no ruído (medido: ~16% com 20 anos, ~21% com 16).
        anos = list(range(2005, 2025))
        zero = sum(ajustar(anos, serie(anos, [-3.0], [], ruido=0.05, semente=s)).joinpoints == () for s in range(200))
        self.assertGreaterEqual(zero / 200, 0.75)

    def test_uma_quebra(self):
        anos = list(range(2005, 2025))
        aj = ajustar(anos, serie(anos, [5.0, -8.0], [2014], ruido=0.02))
        self.assertEqual(aj.joinpoints, (2014,))
        s1, s2 = aj.segmentos
        self.assertEqual((s1.ano_inicio, s1.ano_fim, s2.ano_inicio, s2.ano_fim), (2005, 2014, 2014, 2024))
        for seg, verdadeiro in ((s1, 5.0), (s2, -8.0)):
            self.assertAlmostEqual(seg.apc, verdadeiro, delta=1.0)
            self.assertTrue(seg.ic_inf < verdadeiro < seg.ic_sup)
            self.assertTrue(seg.significativo)
        self.assertAlmostEqual(s1.taxa_fim, s2.taxa_inicio, places=10)  # contínuo no joinpoint

    def test_tres_quebras(self):
        anos = list(range(2007, 2024))  # 17 anos, como serpente no TCC
        verdadeiros = [7.0, -3.0, 8.0, -3.0]
        aj = ajustar(anos, serie(anos, verdadeiros, [2009, 2016, 2019], ruido=0.003))
        self.assertEqual(aj.joinpoints, (2009, 2016, 2019))
        for seg, verdadeiro in zip(aj.segmentos, verdadeiros):
            self.assertAlmostEqual(seg.apc, verdadeiro, delta=1.0)

    def test_aapc_exato(self):
        # Sem ruído: AAPC = média das inclinações ponderada pelos anos de cada segmento.
        anos = list(range(2000, 2020))
        aj = ajustar(anos, serie(anos, [10.0, -5.0], [2005]))
        self.assertEqual(aj.joinpoints, (2005,))
        b = (5 * math.log(1.10) + 14 * math.log(0.95)) / 19
        self.assertAlmostEqual(aj.aapc.apc, 100 * math.expm1(b), places=8)
        # Num trecho dentro de um segmento só, a média é o APC do segmento.
        self.assertAlmostEqual(aj.media(2006, 2012).apc, -5.0, places=8)

    def test_ic_aapc_contem_verdadeiro(self):
        anos = list(range(2005, 2025))
        aj = ajustar(anos, serie(anos, [6.0, -6.0], [2015], ruido=0.03, semente=7))
        b = (10 * math.log(1.06) + 9 * math.log(0.94)) / 19
        aapc = aj.aapc
        self.assertTrue(aapc.ic_inf < 100 * math.expm1(b) < aapc.ic_sup)
        self.assertLess(aapc.ic_inf, aapc.apc)
        self.assertLess(aapc.apc, aapc.ic_sup)

    def test_rejeita_taxa_zero(self):
        with self.assertRaises(ValueError):
            ajustar([2000, 2001, 2002, 2003], [1.0, 0.0, 1.0, 1.0])


def serie_ar1(anos: list[int], apc: float, rho: float, sd: float, semente: int) -> list[float]:
    """Taxas com APC conhecido e erro AR(1) estacionário no log (inovação com desvio `sd`)."""
    rnd = random.Random(semente)
    e, taxas = 0.0, []
    for i, t in enumerate(serie(anos, [apc], [])):
        inov = rnd.gauss(0, sd)
        e = inov / math.sqrt(1 - rho * rho) if i == 0 else rho * e + inov
        taxas.append(t * math.exp(e))
    return taxas


class TestAutocorrelacao(unittest.TestCase):
    """Erros AR(1): ρ por REML e reestimação por Prais-Winsten com os joinpoints fixos."""

    anos = list(range(2007, 2026))  # 19 anos, como as séries do app

    def _cobertura(self, rho: float, correcao: bool, n_sim: int = 300) -> float:
        cobre = 0
        for s in range(n_sim):
            (seg,) = ajustar(self.anos, serie_ar1(self.anos, 4.0, rho, 0.1, s), k_max=0,
                             autocorrelacao=correcao).segmentos
            cobre += seg.ic_inf < 4.0 < seg.ic_sup
        return cobre / n_sim

    def test_reml_quase_sem_vies(self):
        # A autocorrelação simples dos resíduos daria ~0,3 para ρ = 0,6 e ~−0,1 para ρ = 0.
        for rho, faixa in ((0.6, (0.42, 0.66)), (0.0, (-0.07, 0.07))):
            media = sum(ajustar(self.anos, serie_ar1(self.anos, 4.0, rho, 0.1, s), k_max=0).rho
                        for s in range(200)) / 200
            self.assertTrue(faixa[0] < media < faixa[1], (rho, media))

    def test_cobertura_com_autocorrelacao(self):
        # Com ρ = 0,6, sem a correção o IC cobre ~67% das vezes; com ela, ~88% (medido).
        sem, com = self._cobertura(0.6, False), self._cobertura(0.6, True)
        self.assertGreaterEqual(com, 0.82)
        self.assertGreaterEqual(com - sem, 0.10, (sem, com))

    def test_cobertura_sem_autocorrelacao(self):
        # Com ρ = 0, a correção custa pouco: ~92% de cobertura (sem ela, ~95%).
        self.assertGreaterEqual(self._cobertura(0.0, True), 0.88)

    def test_joinpoints_iguais_aos_do_ajuste_comum(self):
        anos = list(range(2005, 2025))
        taxas = serie(anos, [5.0, -8.0], [2014], ruido=0.05, semente=3)
        com, sem = ajustar(anos, taxas), ajustar(anos, taxas, autocorrelacao=False)
        self.assertEqual(com.joinpoints, sem.joinpoints)
        self.assertEqual(sem.rho, 0.0)
        self.assertEqual(com.gl, sem.gl - 1)  # o ρ custa um grau de liberdade

    def test_sem_ruido_rho_zero(self):
        anos = list(range(2000, 2020))
        aj = ajustar(anos, serie(anos, [10.0, -5.0], [2005]))
        self.assertEqual(aj.rho, 0.0)


class TestSerie(unittest.TestCase):
    def test_zero_casos_vira_meio_caso(self):
        s = serie_taxas([2020, 2021, 2022], {2020: 4, 2022: 2}, {2020: 1e6, 2021: 1e6, 2022: 2e6})
        self.assertEqual(s.taxas, [0.4, MEIO_CASO * 0.1, 0.1])
        self.assertEqual(len(s.avisos), 1)
        self.assertIn("2021", s.avisos[0])

    def test_sem_zero_sem_aviso(self):
        s = serie_taxas([2020], {2020: 3}, {2020: 1e5})
        self.assertEqual((s.taxas, s.avisos), ([3.0], []))


if __name__ == "__main__":
    unittest.main()
