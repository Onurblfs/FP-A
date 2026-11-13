# Como plugar a dinâmica VAS para o chefe

## 1. Gerar a base
1. Abra `sql/vas_dinamica_analitica.sql` no DBeaver.
2. Confira as datas em `PARAMETROS`.
3. Execute e exporte para CSV/Excel (`vas_dinamica.csv`).

## 2. Excel (mais rápido)
1. Inserir > Tabela Dinâmica sobre o CSV.
2. **Filtros:** `DSC_SEGMENTACAO`, `DSC_TIPO`, `SITUACAO_CLIENTE_SET`
3. **Linhas:** `TIPO_CONTRIBUICAO`, depois `DSC_PRODUTO`
4. **Valores:** Soma de `VARIACAO`, Soma de `QTD_CLIENTES`
5. Telas prontas:
   - Só `DSC_TIPO = Receita` → fecha os +4,8 mi
   - Só `DSC_TIPO = Desconto` → fecha os +2,7 mi
   - `TIPO_CONTRIBUICAO = RECEITA_NOVA` + quebra `SITUACAO_CLIENTE_SET` → 64% / 36%
   - Filtro `DSC_PRODUTO` contém SKEELO

## 3. Tableau
Conecte no CSV (ou na query se houver conector Oracle) e use os mesmos campos como filtros/dims e `VARIACAO` como medida.
