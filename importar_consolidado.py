"""Importa o arquivo Consolidado.csv para uma tabela Oracle.

O fluxo segue o projeto carga_cognos_db: lê as credenciais da planilha
DB_acess.xlsx, cria/valida a tabela, substitui os dados em uma única transação,
insere em lotes e reconcilia a quantidade gravada antes do commit.
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import re
import sys
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import oracledb
import pandas as pd

LOGGER = logging.getLogger("importar_consolidado")
RAIZ_PROJETO = Path(__file__).resolve().parent
MODOS_VALIDOS = {"substituir", "recriar", "anexar"}
TAMANHO_LOTE_PADRAO = 10_000


@dataclass(frozen=True)
class Config:
    arquivo_csv: Path
    dsn_oracle: str
    schema_destino: str | None
    tabela_destino: str
    modo_carga: str
    arquivo_credenciais: Path
    aba_credenciais: str
    coluna_usuario: str
    coluna_senha: str
    usuario_oracle: str | None
    senha_oracle: str | None
    tamanho_lote: int


def carregar_env(caminho: Path) -> None:
    """Carrega um .env simples sem incluir outra dependência."""
    if not caminho.is_file():
        return

    for linha in caminho.read_text(encoding="utf-8-sig").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        chave, _, valor = linha.partition("=")
        chave = chave.strip()
        valor = valor.strip().strip('"').strip("'")
        if chave:
            os.environ.setdefault(chave, valor)


def valor_obrigatorio(nome: str) -> str:
    valor = os.getenv(nome, "").strip()
    if not valor:
        raise ValueError(
            f"Configuração obrigatória ausente: {nome}. "
            "Copie .env.example para .env e confira os valores."
        )
    return valor


def carregar_config(args: argparse.Namespace) -> Config:
    carregar_env(RAIZ_PROJETO / ".env")

    arquivo_csv = Path(
        args.arquivo
        or os.getenv(
            "ARQUIVO_CSV",
            r"C:\Users\n5919189\Downloads\Consolidado.csv",
        )
    ).expanduser()
    tabela = args.tabela or os.getenv("TABELA_DESTINO", "BI_FT_CONSOLIDADO")
    modo = (args.modo or os.getenv("MODO_CARGA", "substituir")).lower()
    if modo not in MODOS_VALIDOS:
        raise ValueError(
            f"Modo inválido: {modo}. Opções: {', '.join(sorted(MODOS_VALIDOS))}."
        )

    tamanho_lote = int(os.getenv("TAMANHO_LOTE", str(TAMANHO_LOTE_PADRAO)))
    if tamanho_lote <= 0:
        raise ValueError("TAMANHO_LOTE precisa ser maior que zero.")

    return Config(
        arquivo_csv=arquivo_csv,
        dsn_oracle=valor_obrigatorio("DSN_ORACLE"),
        schema_destino=os.getenv("SCHEMA_DESTINO", "").strip() or None,
        tabela_destino=tabela,
        modo_carga=modo,
        arquivo_credenciais=Path(
            os.getenv(
                "ARQUIVO_CREDENCIAIS",
                r"C:\Users\n5919189\Documents\DB_acess.xlsx",
            )
        ).expanduser(),
        aba_credenciais=os.getenv("ABA_CREDENCIAIS", "Plan1"),
        coluna_usuario=os.getenv("COLUNA_USUARIO", "user_dw2"),
        coluna_senha=os.getenv("COLUNA_SENHA", "pass_dw2"),
        usuario_oracle=os.getenv("ORACLE_USER", "").strip() or None,
        senha_oracle=os.getenv("ORACLE_PASSWORD", "").strip() or None,
        tamanho_lote=tamanho_lote,
    )


def validar_identificador(valor: str, nome: str) -> str:
    valor = valor.strip().upper()
    if not re.fullmatch(r"[A-Z][A-Z0-9_$#]{0,29}", valor):
        raise ValueError(f"{nome} Oracle inválido: {valor!r}")
    return valor


def validar_schema(valor: str) -> str:
    valor = valor.strip().upper()
    if re.fullmatch(r"[A-Z][A-Z0-9_$#]{0,29}", valor):
        return valor
    if re.fullmatch(r"[0-9]{1,30}", valor):
        return valor
    raise ValueError(f"Schema Oracle inválido: {valor!r}")


def nome_qualificado(schema: str | None, tabela: str) -> str:
    tabela = validar_identificador(tabela, "Tabela")
    if not schema:
        return tabela
    schema = validar_schema(schema)
    schema_sql = f'"{schema}"' if schema.isdigit() else schema
    return f"{schema_sql}.{tabela}"


def detectar_encoding(caminho: Path) -> str:
    amostra = caminho.read_bytes()[:1_048_576]
    for encoding in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            amostra.decode(encoding)
            return encoding
        except UnicodeDecodeError:
            continue
    return "latin-1"


def detectar_separador(caminho: Path, encoding: str) -> str:
    with caminho.open("r", encoding=encoding, errors="replace", newline="") as arq:
        amostra = arq.read(65_536)

    try:
        return csv.Sniffer().sniff(amostra, delimiters=";,|\t").delimiter
    except csv.Error:
        primeira_linha = amostra.splitlines()[0] if amostra else ""
        return ";" if primeira_linha.count(";") > primeira_linha.count(",") else ","


def ler_csv(caminho: Path) -> pd.DataFrame:
    if not caminho.is_file():
        raise FileNotFoundError(f"CSV não encontrado: {caminho}")

    encoding = detectar_encoding(caminho)
    separador = detectar_separador(caminho, encoding)
    LOGGER.info("Lendo %s | encoding=%s | separador=%r", caminho, encoding, separador)

    df = pd.read_csv(
        caminho,
        sep=separador,
        encoding=encoding,
        low_memory=False,
    )
    df = df.dropna(how="all").dropna(axis=1, how="all")
    if df.empty:
        raise ValueError(f"O arquivo {caminho} não contém linhas de dados.")
    if not len(df.columns):
        raise ValueError(f"O arquivo {caminho} não contém cabeçalho.")
    return df


def normalizar_colunas(df: pd.DataFrame) -> pd.DataFrame:
    """Converte cabeçalhos para identificadores Oracle únicos."""
    df = df.copy()
    novas: list[str] = []
    usadas: set[str] = set()

    for coluna in df.columns:
        nome = unicodedata.normalize("NFKD", str(coluna).strip())
        nome = nome.encode("ascii", errors="ignore").decode("ascii")
        nome = re.sub(r"[^A-Za-z0-9_$#]+", "_", nome).strip("_").upper()
        nome = nome or "COLUNA"
        if not nome[0].isalpha():
            nome = f"C_{nome}"
        nome = nome[:30]

        base = nome
        contador = 2
        while nome in usadas:
            sufixo = f"_{contador}"
            nome = f"{base[: 30 - len(sufixo)]}{sufixo}"
            contador += 1
        usadas.add(nome)
        novas.append(nome)

    df.columns = novas
    return df


def maior_texto(serie: pd.Series) -> int:
    valores = serie.dropna()
    if valores.empty:
        return 0
    return int(valores.astype(str).str.len().max())


def tipo_oracle(serie: pd.Series) -> str:
    if pd.api.types.is_datetime64_any_dtype(serie):
        return "DATE"
    if pd.api.types.is_bool_dtype(serie):
        return "NUMBER(1)"
    if pd.api.types.is_numeric_dtype(serie):
        return "NUMBER"

    tamanho = maior_texto(serie)
    if tamanho > 4_000:
        return "CLOB"
    tamanho = min(4_000, max(50, ((tamanho + 49) // 50) * 50))
    return f"VARCHAR2({tamanho} CHAR)"


def ddl_colunas(df: pd.DataFrame) -> str:
    definicoes = [f"    {coluna} {tipo_oracle(df[coluna])}" for coluna in df.columns]
    return "(\n" + ",\n".join(definicoes) + "\n)"


def converter_valor(valor: Any) -> Any:
    if valor is None or pd.isna(valor):
        return None
    if isinstance(valor, pd.Timestamp):
        return valor.to_pydatetime()
    if hasattr(valor, "item"):
        return valor.item()
    return valor


def preparar_linhas(df: pd.DataFrame) -> list[tuple[Any, ...]]:
    return [
        tuple(converter_valor(valor) for valor in linha)
        for linha in df.itertuples(index=False, name=None)
    ]


def ler_credenciais(config: Config) -> tuple[str, str]:
    if config.usuario_oracle or config.senha_oracle:
        if not config.usuario_oracle or not config.senha_oracle:
            raise ValueError(
                "ORACLE_USER e ORACLE_PASSWORD precisam ser definidos juntos."
            )
        return config.usuario_oracle, config.senha_oracle

    if not config.arquivo_credenciais.is_file():
        raise FileNotFoundError(
            f"Planilha de credenciais não encontrada: {config.arquivo_credenciais}"
        )

    credenciais = pd.read_excel(
        config.arquivo_credenciais,
        sheet_name=config.aba_credenciais,
        dtype=str,
    )
    credenciais.columns = [str(coluna).strip() for coluna in credenciais.columns]
    faltantes = {
        config.coluna_usuario,
        config.coluna_senha,
    }.difference(credenciais.columns)
    if faltantes:
        raise KeyError(
            "Colunas ausentes na planilha de credenciais: "
            + ", ".join(sorted(faltantes))
        )

    validas = credenciais.dropna(
        subset=[config.coluna_usuario, config.coluna_senha]
    )
    if validas.empty:
        raise ValueError("A planilha não contém credenciais preenchidas.")

    usuario = str(validas.iloc[0][config.coluna_usuario]).strip()
    senha = str(validas.iloc[0][config.coluna_senha]).strip()
    if not usuario or not senha:
        raise ValueError("Usuário ou senha Oracle estão vazios.")
    return usuario, senha


class CargaOracle:
    def __init__(self, dsn: str, usuario: str, senha: str, tamanho_lote: int):
        self.dsn = dsn
        self.usuario = usuario
        self.senha = senha
        self.tamanho_lote = tamanho_lote

    def conectar(self):
        return oracledb.connect(
            user=self.usuario,
            password=self.senha,
            dsn=self.dsn,
        )

    @staticmethod
    def tabela_existe(cursor, owner: str, tabela: str) -> bool:
        cursor.execute(
            """
            SELECT COUNT(*)
              FROM ALL_TABLES
             WHERE OWNER = :owner
               AND TABLE_NAME = :tabela
            """,
            owner=owner,
            tabela=tabela,
        )
        return int(cursor.fetchone()[0]) > 0

    @staticmethod
    def validar_estrutura(cursor, owner: str, tabela: str, colunas: list[str]) -> None:
        cursor.execute(
            """
            SELECT COLUMN_NAME
              FROM ALL_TAB_COLUMNS
             WHERE OWNER = :owner
               AND TABLE_NAME = :tabela
            """,
            owner=owner,
            tabela=tabela,
        )
        existentes = {linha[0] for linha in cursor.fetchall()}
        faltantes = set(colunas).difference(existentes)
        if faltantes:
            raise RuntimeError(
                f"A tabela {owner}.{tabela} não possui as colunas: "
                + ", ".join(sorted(faltantes))
                + ". Use --modo recriar para reconstruir a tabela."
            )

    def preparar_tabela(
        self,
        df: pd.DataFrame,
        schema: str | None,
        tabela: str,
        modo: str,
    ) -> str:
        tabela = validar_identificador(tabela, "Tabela")
        tabela_sql = nome_qualificado(schema, tabela)

        with self.conectar() as conexao, conexao.cursor() as cursor:
            if schema:
                owner = validar_schema(schema)
            else:
                cursor.execute("SELECT USER FROM DUAL")
                owner = str(cursor.fetchone()[0]).upper()

            existe = self.tabela_existe(cursor, owner, tabela)
            if existe and modo == "recriar":
                cursor.execute(f"DROP TABLE {tabela_sql}")
                existe = False
                LOGGER.info("Tabela removida para recriação: %s", tabela_sql)

            if not existe:
                cursor.execute(f"CREATE TABLE {tabela_sql} {ddl_colunas(df)}")
                LOGGER.info("Tabela criada: %s", tabela_sql)
            else:
                self.validar_estrutura(cursor, owner, tabela, list(df.columns))
            conexao.commit()
        return owner

    def carregar(
        self,
        df: pd.DataFrame,
        schema: str | None,
        tabela: str,
        modo: str,
    ) -> int:
        tabela = validar_identificador(tabela, "Tabela")
        tabela_sql = nome_qualificado(schema, tabela)
        owner = self.preparar_tabela(df, schema, tabela, modo)
        linhas = preparar_linhas(df)
        binds = ", ".join(f":{indice}" for indice in range(1, len(df.columns) + 1))
        colunas_sql = ", ".join(df.columns)
        insert_sql = (
            f"INSERT INTO {tabela_sql} ({colunas_sql}) VALUES ({binds})"
        )

        with self.conectar() as conexao, conexao.cursor() as cursor:
            antes = 0
            removidos = 0
            if modo in {"substituir", "recriar"}:
                cursor.execute(f"DELETE FROM {tabela_sql}")
                removidos = max(cursor.rowcount, 0)
            else:
                cursor.execute(f"SELECT COUNT(*) FROM {tabela_sql}")
                antes = int(cursor.fetchone()[0])

            inseridos = 0
            for inicio in range(0, len(linhas), self.tamanho_lote):
                lote = linhas[inicio : inicio + self.tamanho_lote]
                cursor.executemany(insert_sql, lote)
                inseridos += len(lote)
                LOGGER.info("Linhas enviadas: %s", f"{inseridos:,}")

            cursor.execute(f"SELECT COUNT(*) FROM {tabela_sql}")
            total = int(cursor.fetchone()[0])
            esperado = antes + inseridos
            if total != esperado:
                conexao.rollback()
                raise RuntimeError(
                    f"Reconciliação falhou em {tabela_sql}: "
                    f"esperado={esperado}, encontrado={total}."
                )
            conexao.commit()

            LOGGER.info(
                "%s | removidas=%s | inseridas=%s | total=%s",
                tabela_sql,
                f"{removidos:,}",
                f"{inseridos:,}",
                f"{total:,}",
            )
            self.coletar_estatisticas(cursor, owner, tabela)
            return inseridos

    @staticmethod
    def coletar_estatisticas(cursor, owner: str, tabela: str) -> None:
        try:
            cursor.execute(
                """
                BEGIN
                    DBMS_STATS.GATHER_TABLE_STATS(
                        ownname => :owner,
                        tabname => :tabela,
                        cascade => TRUE,
                        no_invalidate => FALSE
                    );
                END;
                """,
                owner=owner,
                tabela=tabela,
            )
        except oracledb.DatabaseError as exc:
            LOGGER.warning("DBMS_STATS não executado: %s", exc)


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Importa o Consolidado.csv para uma tabela Oracle."
    )
    parser.add_argument("--arquivo", help="Caminho alternativo do CSV")
    parser.add_argument("--tabela", help="Tabela de destino")
    parser.add_argument(
        "--modo",
        choices=sorted(MODOS_VALIDOS),
        help="substituir (padrão), recriar ou anexar",
    )
    parser.add_argument(
        "--somente-validar",
        action="store_true",
        help="Valida e apresenta o CSV sem acessar o Oracle",
    )
    return parser


def executar(args: argparse.Namespace) -> int:
    config = carregar_config(args)
    df = normalizar_colunas(ler_csv(config.arquivo_csv))
    df["DT_CARGA"] = datetime.now(timezone.utc).astimezone().replace(tzinfo=None)
    df["ARQUIVO_ORIGEM"] = config.arquivo_csv.name

    LOGGER.info("Linhas=%s | colunas=%s", f"{len(df):,}", len(df.columns))
    LOGGER.info("Colunas: %s", ", ".join(df.columns))
    if args.somente_validar:
        LOGGER.info("Validação concluída; nenhuma alteração foi feita no banco.")
        return 0

    usuario, senha = ler_credenciais(config)
    LOGGER.info(
        "Conectando ao DSN=%s | tabela=%s | usuário=%s",
        config.dsn_oracle,
        nome_qualificado(config.schema_destino, config.tabela_destino),
        usuario,
    )
    carga = CargaOracle(
        config.dsn_oracle,
        usuario,
        senha,
        config.tamanho_lote,
    )
    inseridos = carga.carregar(
        df,
        config.schema_destino,
        config.tabela_destino,
        config.modo_carga,
    )
    LOGGER.info("Carga finalizada com sucesso: %s linhas.", f"{inseridos:,}")
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-8s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    try:
        return executar(criar_parser().parse_args())
    except Exception:
        LOGGER.exception("Falha na importação.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
