-- Passo 3 (resumo): quantos clientes foram de qual valor para qual valor.
--
-- Antes de executar, ajuste em PARAMETROS as duas datas e o FILTRO_PRODUTO
-- (os mesmos de vas_produto_por_cliente.sql).
--
-- Agrupa os clientes do passo 3 pelo par (valor no mês anterior, valor no mês
-- atual) de cada produto. Serve para ver o motivo da variação sem abrir a
-- lista de clientes: VAL_MES_ANTERIOR = 0 é cliente que não tinha o produto,
-- VAL_MES_ATUAL = 0 é cliente que deixou de ter, e os demais pares mostram
-- mudança de valor em quem já tinha.
--
-- A ordenação é pelo módulo da variação total, então os pares que mais
-- explicam a diferença entre os meses aparecem primeiro.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL,
        'SKEELO%' AS FILTRO_PRODUTO
    FROM DUAL
),
POR_CLIENTE AS (
    SELECT
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        T.DSC_PRODUTO,
        ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                       THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ANTERIOR,
        ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                       THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ATUAL
    FROM u92870757.BI_FP_RECEITA_FIXA T
    CROSS JOIN PARAMETROS P
    WHERE T.DSC_TIPO_PRODUTO = 'NT'
      AND T.DSC_TIPO = 'Receita'
      AND T.DSC_SUBTIPO = 'Bruta'
      AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
      AND T.DSC_PRODUTO LIKE P.FILTRO_PRODUTO
    GROUP BY
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        T.DSC_PRODUTO
)
SELECT
    DSC_PRODUTO,
    VAL_MES_ANTERIOR,
    VAL_MES_ATUAL,
    COUNT(*) AS QTD_CLIENTES,
    SUM(VAL_MES_ATUAL - VAL_MES_ANTERIOR) AS VARIACAO_TOTAL
FROM POR_CLIENTE
GROUP BY
    DSC_PRODUTO,
    VAL_MES_ANTERIOR,
    VAL_MES_ATUAL
ORDER BY ABS(SUM(VAL_MES_ATUAL - VAL_MES_ANTERIOR)) DESC
