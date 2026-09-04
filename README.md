# Adicionar SEGMENTO ao Consolidado.csv

Este projeto atualiza:

```text
\\cllgpdw8551.corp.clarobr\PLANEJAMENTO_FINANCEIRO\BASES\
RECEITA_EMPRESARIAL\CONSULTA_SEGMENTO\Consolidado.csv
```

Ele consulta `DWH.VW_BI_HIS_SEGMENTO_CARTEIRA` no Oracle, cruza os registros
por `CNPJ14` e adiciona a coluna `SEGMENTO` ao CSV.

## Tratamento do CNPJ14

O cruzamento normaliza os dois lados para 14 dígitos. Assim, valores do CSV
como estes são considerados iguais:

```text
12345678000190.0
12345678000190
12.345.678/0001-90
```

O `.0` também é removido da coluna CNPJ14 salva no arquivo.

Se a consulta retornar mais de um `SEGMENTO` diferente para o mesmo CNPJ14, o
programa interrompe sem alterar o CSV. Isso evita duplicar linhas ou escolher
um segmento histórico arbitrariamente.

## Execução

1. Confirme que o Python 3.11 ou superior está instalado.
2. Dê duplo clique em `EXECUTAR.bat`.
3. Na primeira execução, confira o `.env` aberto no Bloco de Notas.
4. Feche o Bloco de Notas para continuar.

Antes de substituir o arquivo, o programa cria uma cópia em:

```text
\\cllgpdw8551.corp.clarobr\PLANEJAMENTO_FINANCEIRO\BASES\
RECEITA_EMPRESARIAL\CONSULTA_SEGMENTO\backup\
Consolidado_AAAAMMDD_HHMMSS.csv
```

O separador e o encoding originais são preservados. São aceitos CSVs
separados por vírgula, ponto e vírgula, pipe ou tabulação e codificados em
UTF-8, Windows-1252 ou Latin-1.

## Configuração padrão

| Configuração | Valor |
|---|---|
| DSN | `P00DW1` |
| CSV | `\\cllgpdw8551.corp.clarobr\...\CONSULTA_SEGMENTO\Consolidado.csv` |
| Credenciais | `C:\Users\n5919189\Documents\DB_acess.xlsx` |

A planilha de credenciais deve possuir `user_dw2` e `pass_dw2` na aba `Plan1`.
Esses valores podem ser alterados no `.env`.

## Uso manual

```powershell
python -m pip install -r requirements.txt
python adicionar_segmento.py
```

Validar o cruzamento sem gravar:

```powershell
python adicionar_segmento.py --somente-validar
```

Salvar em outro arquivo:

```powershell
python adicionar_segmento.py `
  --saida "\\cllgpdw8551.corp.clarobr\...\Consolidado_com_segmento.csv"
```

O `.env` contém configurações locais e não deve ser enviado ao Git.
