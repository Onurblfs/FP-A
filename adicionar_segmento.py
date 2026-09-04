"""Adiciona SEGMENTO ao Consolidado.csv cruzando o CNPJ14 com o DWH Oracle."""

from __future__ import annotations

import argparse
import csv
import logging
import os
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

import pandas as pd

try:
    import oracledb
except ImportError:
    import cx_Oracle as oracledb

LOGGER = logging.getLogger("adicionar_segmento")
EXECUTANDO_NO_JUPYTER = "ipykernel" in sys.modules or "__file__" not in globals()
RAIZ_PROJETO = (
    Path(__file__).resolve().parent if "__file__" in globals() else Path.cwd()
)

CONSULTA_SEGMENTOS = """
SELECT
    NUM_RAIZ_CNPJ AS CNPJ8,
    NUM_RAIZ_CNPJ_CONTROLADOR,
    NUM_CNPJ AS CNPJ14,
    DSC_PORTE_EMPRESA AS SEGMENTO
FROM DWH.VW_BI_HIS_SEGMENTO_CARTEIRA
GROUP BY
    NUM_RAIZ_CNPJ,
    NUM_RAIZ_CNPJ_CONTROLADOR,
    NUM_CNPJ,
    DSC_PORTE_EMPRESA
"""


@dataclass(frozen=True)
class Config:
    arquivo_csv: Path
    dsn_oracle: str
    arquivo_credenciais: Path
    aba_credenciais: str
    coluna_usuario: str
    coluna_senha: str
    usuario_oracle: str | None
    senha_oracle: str | None


@dataclass(frozen=True)
class FormatoCsv:
    encoding: str
    separador: str


@dataclass(frozen=True)
class ResultadoCruzamento:
    dados: pd.DataFrame
    total: int
    encontrados: int
    sem_segmento: int
    cnpjs_invalidos: int


def carregar_env(caminho: Path) -> None:
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


def carregar_config(args: argparse.Namespace) -> Config:
    carregar_env(RAIZ_PROJETO / ".env")
    arquivo = args.arquivo or os.getenv(
        "ARQUIVO_CSV",
        (
            r"\\cllgpdw8551.corp.clarobr\PLANEJAMENTO_FINANCEIRO"
            r"\BASES\RECEITA_EMPRESARIAL\CONSULTA_SEGMENTO\Consolidado.csv"
        ),
    )
    return Config(
        arquivo_csv=Path(arquivo).expanduser(),
        dsn_oracle=os.getenv("DSN_ORACLE", "P00DW1").strip() or "P00DW1",
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
    )


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


def ler_csv(caminho: Path) -> tuple[pd.DataFrame, FormatoCsv]:
    if not caminho.is_file():
        raise FileNotFoundError(f"CSV não encontrado: {caminho}")

    formato = FormatoCsv(
        encoding=detectar_encoding(caminho),
        separador="",
    )
    formato = FormatoCsv(
        encoding=formato.encoding,
        separador=detectar_separador(caminho, formato.encoding),
    )
    LOGGER.info(
        "Lendo %s | encoding=%s | separador=%r",
        caminho,
        formato.encoding,
        formato.separador,
    )
    dados = pd.read_csv(
        caminho,
        sep=formato.separador,
        encoding=formato.encoding,
        dtype=str,
        low_memory=False,
    )
    dados = dados.dropna(how="all").dropna(axis=1, how="all")
    if dados.empty:
        raise ValueError(f"O arquivo {caminho} não contém dados.")
    return dados, formato


def normalizar_nome_coluna(nome: object) -> str:
    return re.sub(r"[^A-Z0-9]", "", str(nome).upper())


def localizar_coluna_cnpj14(dados: pd.DataFrame) -> str:
    correspondencias = [
        coluna
        for coluna in dados.columns
        if normalizar_nome_coluna(coluna) in {"CNPJ14", "NUMCNPJ"}
    ]
    if not correspondencias:
        raise KeyError(
            "O CSV não possui a coluna CNPJ14. "
            f"Colunas encontradas: {', '.join(map(str, dados.columns))}"
        )
    if len(correspondencias) > 1:
        raise KeyError(
            "Mais de uma possível coluna CNPJ14 foi encontrada: "
            + ", ".join(map(str, correspondencias))
        )
    return str(correspondencias[0])


def normalizar_cnpj14(valor: object) -> str | None:
    """Transforma 12345678000190.0, números e CNPJs formatados em 14 dígitos."""
    if valor is None or pd.isna(valor):
        return None

    texto = str(valor).strip()
    if not texto:
        return None

    if "e" in texto.lower():
        try:
            numero = Decimal(texto.replace(",", "."))
            if numero != numero.to_integral_value():
                return None
            digitos = str(int(numero))
        except (InvalidOperation, ValueError):
            return None
    else:
        texto = re.sub(r"[.,]0+$", "", texto)
        if not re.fullmatch(r"[\d./\-\s]+", texto):
            return None
        digitos = re.sub(r"\D", "", texto)

    if not digitos or len(digitos) > 14:
        return None
    return digitos.zfill(14)


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


def consultar_segmentos(dsn: str, usuario: str, senha: str) -> pd.DataFrame:
    LOGGER.info("Consultando segmentos no DSN=%s...", dsn)
    with oracledb.connect(  # noqa: SIM117
        user=usuario,
        password=senha,
        dsn=dsn,
    ) as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(CONSULTA_SEGMENTOS)
            colunas = [
                str(descricao[0]).upper() for descricao in cursor.description
            ]
            linhas = cursor.fetchall()
    LOGGER.info("Linhas retornadas pela consulta: %s", f"{len(linhas):,}")
    return pd.DataFrame.from_records(linhas, columns=colunas)


def preparar_mapa_segmentos(segmentos: pd.DataFrame) -> dict[str, str]:
    obrigatorias = {"CNPJ14", "SEGMENTO"}
    faltantes = obrigatorias.difference(segmentos.columns)
    if faltantes:
        raise KeyError(
            "A consulta não retornou as colunas: " + ", ".join(sorted(faltantes))
        )

    mapa = segmentos.loc[:, ["CNPJ14", "SEGMENTO"]].copy()
    mapa["_CNPJ14_CHAVE"] = mapa["CNPJ14"].map(normalizar_cnpj14)
    mapa["SEGMENTO"] = mapa["SEGMENTO"].astype("string").str.strip()
    mapa = mapa.dropna(subset=["_CNPJ14_CHAVE", "SEGMENTO"])
    mapa = mapa.loc[mapa["SEGMENTO"] != ""].drop_duplicates()

    quantidades = mapa.groupby("_CNPJ14_CHAVE")["SEGMENTO"].nunique()
    conflitantes = quantidades.loc[quantidades > 1]
    if not conflitantes.empty:
        exemplos = ", ".join(conflitantes.index[:10])
        raise ValueError(
            f"A consulta retornou segmentos diferentes para "
            f"{len(conflitantes)} CNPJ(s). Exemplos: {exemplos}. "
            "A consulta precisa definir qual registro histórico deve prevalecer."
        )

    mapa = mapa.drop_duplicates("_CNPJ14_CHAVE")
    return dict(zip(mapa["_CNPJ14_CHAVE"], mapa["SEGMENTO"]))


def cruzar_segmentos(
    dados: pd.DataFrame,
    segmentos: pd.DataFrame,
) -> ResultadoCruzamento:
    resultado = dados.copy()
    coluna_cnpj = localizar_coluna_cnpj14(resultado)
    chaves = resultado[coluna_cnpj].map(normalizar_cnpj14)
    mapa = preparar_mapa_segmentos(segmentos)

    # Limpa o ".0" no próprio CNPJ14 sem apagar valores que não puderam ser lidos.
    resultado[coluna_cnpj] = chaves.where(chaves.notna(), resultado[coluna_cnpj])
    if "SEGMENTO" in resultado.columns:
        resultado = resultado.drop(columns=["SEGMENTO"])
    resultado["SEGMENTO"] = chaves.map(mapa)

    total = len(resultado)
    encontrados = int(resultado["SEGMENTO"].notna().sum())
    invalidos = int(chaves.isna().sum())
    return ResultadoCruzamento(
        dados=resultado,
        total=total,
        encontrados=encontrados,
        sem_segmento=total - encontrados,
        cnpjs_invalidos=invalidos,
    )


def salvar_csv(
    dados: pd.DataFrame,
    destino: Path,
    formato: FormatoCsv,
    criar_backup: bool,
) -> Path | None:
    destino.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    if criar_backup and destino.is_file():
        pasta_backup = destino.parent / "backup"
        pasta_backup.mkdir(parents=True, exist_ok=True)
        instante = datetime.now().astimezone().strftime("%Y%m%d_%H%M%S")
        backup = pasta_backup / f"{destino.stem}_{instante}{destino.suffix}"
        shutil.copy2(destino, backup)
        LOGGER.info("Backup criado: %s", backup)

    descritor, temporario_nome = tempfile.mkstemp(
        prefix=f".{destino.stem}_",
        suffix=".tmp",
        dir=destino.parent,
    )
    os.close(descritor)
    temporario = Path(temporario_nome)
    try:
        dados.to_csv(
            temporario,
            index=False,
            sep=formato.separador,
            encoding=formato.encoding,
            lineterminator="\n",
        )
        os.replace(temporario, destino)
    finally:
        temporario.unlink(missing_ok=True)
    return backup


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Adiciona SEGMENTO ao Consolidado.csv pelo CNPJ14."
    )
    parser.add_argument("--arquivo", help="Caminho alternativo do CSV de entrada")
    parser.add_argument(
        "--saida",
        help="Salva em outro arquivo; por padrão atualiza o CSV de entrada",
    )
    parser.add_argument(
        "--sem-backup",
        action="store_true",
        help="Não cria backup quando o arquivo de destino já existe",
    )
    parser.add_argument(
        "--somente-validar",
        action="store_true",
        help="Executa consulta e cruzamento, mas não grava o CSV",
    )
    return parser


def executar(args: argparse.Namespace) -> int:
    config = carregar_config(args)
    dados, formato = ler_csv(config.arquivo_csv)
    usuario, senha = ler_credenciais(config)
    segmentos = consultar_segmentos(config.dsn_oracle, usuario, senha)
    resultado = cruzar_segmentos(dados, segmentos)

    LOGGER.info(
        "Cruzamento: total=%s | com segmento=%s | sem segmento=%s | CNPJ inválido=%s",
        f"{resultado.total:,}",
        f"{resultado.encontrados:,}",
        f"{resultado.sem_segmento:,}",
        f"{resultado.cnpjs_invalidos:,}",
    )
    if args.somente_validar:
        LOGGER.info("Validação concluída; o CSV não foi alterado.")
        return 0

    destino = Path(args.saida).expanduser() if args.saida else config.arquivo_csv
    salvar_csv(
        resultado.dados,
        destino,
        formato,
        criar_backup=not args.sem_backup,
    )
    LOGGER.info("CSV atualizado com sucesso: %s", destino)
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-8s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    try:
        argumentos = [] if EXECUTANDO_NO_JUPYTER else None
        return executar(criar_parser().parse_args(argumentos))
    except Exception:
        LOGGER.exception("Falha ao adicionar SEGMENTO ao CSV.")
        return 1


if __name__ == "__main__":
    codigo_saida = main()
    if not EXECUTANDO_NO_JUPYTER:
        sys.exit(codigo_saida)
