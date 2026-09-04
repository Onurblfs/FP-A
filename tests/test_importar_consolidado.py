import tempfile
import unittest
from pathlib import Path

import pandas as pd

from importar_consolidado import (
    ddl_colunas,
    detectar_encoding,
    detectar_separador,
    ler_csv,
    nome_qualificado,
    normalizar_colunas,
    preparar_linhas,
    validar_identificador,
)


class LeituraCsvTests(unittest.TestCase):
    def test_detecta_cp1252_e_ponto_e_virgula(self):
        with tempfile.TemporaryDirectory() as pasta:
            caminho = Path(pasta) / "Consolidado.csv"
            caminho.write_bytes(
                "Região;Código;Valor\nSão Paulo;001;10,50\n".encode("cp1252")
            )

            encoding = detectar_encoding(caminho)
            self.assertEqual(encoding, "cp1252")
            self.assertEqual(detectar_separador(caminho, encoding), ";")

            df = ler_csv(caminho)
            self.assertEqual(list(df.columns), ["Região", "Código", "Valor"])
            self.assertEqual(len(df), 1)

    def test_normaliza_colunas_duplicadas_e_numericas(self):
        df = pd.DataFrame([[1, 2, 3]], columns=["Região", "Regiao", "2026 valor"])
        resultado = normalizar_colunas(df)
        self.assertEqual(
            list(resultado.columns),
            ["REGIAO", "REGIAO_2", "C_2026_VALOR"],
        )


class OracleSqlTests(unittest.TestCase):
    def test_nome_qualificado(self):
        self.assertEqual(
            nome_qualificado("U93314735", "bi_ft_consolidado"),
            "U93314735.BI_FT_CONSOLIDADO",
        )
        self.assertEqual(
            nome_qualificado("93314735", "dados"),
            '"93314735".DADOS',
        )

    def test_rejeita_identificador_injetavel(self):
        with self.assertRaises(ValueError):
            validar_identificador("DADOS; DROP TABLE X", "Tabela")

    def test_gera_ddl_e_linhas_oracle(self):
        df = pd.DataFrame(
            {
                "CODIGO": [1, 2],
                "DESCRICAO": ["A", None],
                "DT_CARGA": pd.to_datetime(["2026-01-01", "2026-01-02"]),
            }
        )

        ddl = ddl_colunas(df)
        self.assertIn("CODIGO NUMBER", ddl)
        self.assertIn("DESCRICAO VARCHAR2(50 CHAR)", ddl)
        self.assertIn("DT_CARGA DATE", ddl)

        linhas = preparar_linhas(df)
        self.assertEqual(linhas[1][1], None)
        self.assertEqual(linhas[0][2].year, 2026)


if __name__ == "__main__":
    unittest.main()
