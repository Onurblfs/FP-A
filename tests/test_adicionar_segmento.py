import tempfile
import unittest
from pathlib import Path

import pandas as pd

from adicionar_segmento import (
    FormatoCsv,
    cruzar_segmentos,
    ler_csv,
    normalizar_cnpj14,
    preparar_mapa_segmentos,
    salvar_csv,
)


class NormalizacaoCnpjTests(unittest.TestCase):
    def test_remove_decimal_e_completa_zeros(self):
        self.assertEqual(normalizar_cnpj14("12345678000190.0"), "12345678000190")
        self.assertEqual(normalizar_cnpj14("123.0"), "00000000000123")

    def test_aceita_formatado_numerico_e_notacao_cientifica(self):
        self.assertEqual(normalizar_cnpj14("12.345.678/0001-90"), "12345678000190")
        self.assertEqual(normalizar_cnpj14(12345678000190), "12345678000190")
        self.assertEqual(normalizar_cnpj14("1.2345678000190E+13"), "12345678000190")

    def test_rejeita_valores_invalidos(self):
        self.assertIsNone(normalizar_cnpj14(""))
        self.assertIsNone(normalizar_cnpj14("CNPJ desconhecido"))
        self.assertIsNone(normalizar_cnpj14("123456789012345"))


class CruzamentoTests(unittest.TestCase):
    def test_adiciona_segmento_sem_duplicar_linhas(self):
        csv = pd.DataFrame(
            {
                "cnpj14": ["12345678000190.0", "00000000000123.0", "inválido"],
                "VALOR": ["10", "20", "30"],
            }
        )
        oracle = pd.DataFrame(
            {
                "CNPJ14": [12345678000190, 123, 123],
                "SEGMENTO": ["EMPRESAS", "PME", "PME"],
            }
        )

        resultado = cruzar_segmentos(csv, oracle)

        self.assertEqual(len(resultado.dados), 3)
        self.assertEqual(
            list(resultado.dados["SEGMENTO"].fillna("")),
            ["EMPRESAS", "PME", ""],
        )
        self.assertEqual(resultado.dados.iloc[0]["cnpj14"], "12345678000190")
        self.assertEqual(resultado.encontrados, 2)
        self.assertEqual(resultado.sem_segmento, 1)
        self.assertEqual(resultado.cnpjs_invalidos, 1)

    def test_interrompe_quando_um_cnpj_tem_segmentos_conflitantes(self):
        oracle = pd.DataFrame(
            {
                "CNPJ14": [123, 123],
                "SEGMENTO": ["PME", "CORPORATE"],
            }
        )
        with self.assertRaisesRegex(ValueError, "segmentos diferentes"):
            preparar_mapa_segmentos(oracle)


class GravacaoTests(unittest.TestCase):
    def test_grava_atomicamente_e_cria_backup(self):
        with tempfile.TemporaryDirectory() as pasta:
            destino = Path(pasta) / "Consolidado.csv"
            destino.write_text("CNPJ14;VALOR\n123.0;10\n", encoding="cp1252")
            dados, _ = ler_csv(destino)
            dados["SEGMENTO"] = "PME"

            backup = salvar_csv(
                dados,
                destino,
                FormatoCsv(encoding="cp1252", separador=";"),
                criar_backup=True,
            )

            self.assertIsNotNone(backup)
            self.assertTrue(backup.is_file())
            self.assertEqual(
                backup.read_text(encoding="cp1252"),
                "CNPJ14;VALOR\n123.0;10\n",
            )
            atualizado = pd.read_csv(destino, sep=";", dtype=str)
            self.assertEqual(atualizado.iloc[0]["SEGMENTO"], "PME")


if __name__ == "__main__":
    unittest.main()
