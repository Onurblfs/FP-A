# Importação do Consolidado.csv para Oracle

Este projeto importa:

```text
C:\Users\n5919189\Downloads\Consolidado.csv
```

para a tabela Oracle `U93314735.BI_FT_CONSOLIDADO`, usando o mesmo padrão do
projeto `carga_cognos_db`.

## Funcionamento

- detecta automaticamente CSV separado por vírgula, ponto e vírgula, pipe ou
  tabulação;
- aceita arquivos UTF-8, Windows-1252 e Latin-1;
- normaliza os cabeçalhos para nomes Oracle;
- cria a tabela automaticamente quando ela não existe;
- no modo padrão, executa `DELETE` e `INSERT` na mesma transação;
- insere em lotes de 10.000 linhas;
- somente confirma a transação depois de reconciliar a contagem;
- adiciona `DT_CARGA` e `ARQUIVO_ORIGEM`.

## Configuração

1. Confirme que o Python 3.11 ou superior está instalado.
2. Dê duplo clique em `EXECUTAR.bat`.
3. Na primeira execução, confira o arquivo `.env` aberto no Bloco de Notas.
4. Salve o `.env`; a carga continuará quando o Bloco de Notas for fechado.

Valores padrão:

| Configuração | Valor |
|---|---|
| DSN | `P00DW1` |
| Schema | `U93314735` |
| Tabela | `BI_FT_CONSOLIDADO` |
| CSV | `C:\Users\n5919189\Downloads\Consolidado.csv` |
| Credenciais | `C:\Users\n5919189\Documents\DB_acess.xlsx` |

A planilha de credenciais deve possuir as colunas `user_dw2` e `pass_dw2` na
aba `Plan1`. Ajuste esses nomes no `.env` quando necessário.

## Execução manual

Instale as dependências e execute:

```powershell
python -m pip install -r requirements.txt
python importar_consolidado.py
```

Para validar a leitura sem alterar o banco:

```powershell
python importar_consolidado.py --somente-validar
```

Outras opções:

```powershell
python importar_consolidado.py --tabela OUTRA_TABELA
python importar_consolidado.py --arquivo "C:\outra-pasta\arquivo.csv"
python importar_consolidado.py --modo anexar
python importar_consolidado.py --modo recriar
```

Modos:

- `substituir`: apaga e substitui os dados, preservando a estrutura;
- `anexar`: mantém os dados existentes;
- `recriar`: remove e recria a tabela conforme as colunas atuais do CSV.

O `.env` contém configurações locais e não deve ser enviado ao Git.
