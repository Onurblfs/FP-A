-- Fecha a variação de Desconto/Bruta de NT por tipo de movimento.
--
-- Desconto é negativo. Interpretação de TIPO_CONTRIBUICAO:
--   DESCONTO_SUMIU     = tinha desconto em set e zero em out (ajuda a "queda")
--   DESCONTO_MENOR     = ainda tem, mas menos negativo (ajuda a "queda")
--   DESCONTO_NOVO      = zero em set e desconto em out (aumenta desconto)
--   DESCONTO_MAIOR     = desconto ficou mais negativo (aumenta desconto)
--
-- A soma de VARIACAO deve bater com Desconto/Bruta no resumo dos dois
-- movimentos. Ajuste datas e, se quiser um produto só, FILTRO_PRODUTO.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL,
        '%' AS FILTRO_PRODUTO
    FROM DUAL
),
BASE AS (
    SELECT
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        T.DSC_PRODUTO,
        T.DSC_ARTIGO,
        SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                 THEN T.VAL_CALCULADO ELSE 0 END) AS VAL_MES_ANTERIOR,
        SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                 THEN T.VAL_CALCULADO ELSE 0 END) AS VAL_MES_ATUAL
    FROM u92870757.BI_FP_RECEITA_FIXA T
    CROSS JOIN PARAMETROS P
    WHERE T.DSC_TIPO_PRODUTO = 'NT'
      AND T.DSC_TIPO = 'Desconto'
      AND T.DSC_SUBTIPO = 'Bruta'
      AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
      AND T.DSC_PRODUTO LIKE P.FILTRO_PRODUTO
    GROUP BY
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        T.DSC_PRODUTO,
        T.DSC_ARTIGO
),
POR_CLIENTE AS (
    SELECT
        COD_OPERADORA,
        NUM_CONTRATO,
        DSC_PRODUTO,
        DSC_ARTIGO,
        VAL_MES_ANTERIOR,
        VAL_MES_ATUAL,
        VAL_MES_ATUAL - VAL_MES_ANTERIOR AS VARIACAO,
        CASE
            WHEN VAL_MES_ANTERIOR < 0 AND VAL_MES_ATUAL = 0
                THEN 'DESCONTO_SUMIU'
            WHEN VAL_MES_ANTERIOR = 0 AND VAL_MES_ATUAL < 0
                THEN 'DESCONTO_NOVO'
            WHEN VAL_MES_ATUAL > VAL_MES_ANTERIOR
                THEN 'DESCONTO_MENOR'
            WHEN VAL_MES_ATUAL < VAL_MES_ANTERIOR
                THEN 'DESCONTO_MAIOR'
            ELSE 'SEM_VARIACAO'
        END AS TIPO_CONTRIBUICAO
    FROM BASE
    WHERE VAL_MES_ATUAL <> VAL_MES_ANTERIOR
)
SELECT *
FROM (
    SELECT
        DSC_PRODUTO,
        DSC_ARTIGO,
        TIPO_CONTRIBUICAO,
        COUNT(*) AS QTD_CLIENTES,
        ROUND(SUM(VAL_MES_ANTERIOR), 2) AS VAL_MES_ANTERIOR,
        ROUND(SUM(VAL_MES_ATUAL), 2) AS VAL_MES_ATUAL,
        ROUND(SUM(VARIACAO), 2) AS VARIACAO
    FROM POR_CLIENTE
    GROUP BY
        DSC_PRODUTO,
        DSC_ARTIGO,
        TIPO_CONTRIBUICAO
) R
ORDER BY ABS(R.VARIACAO) DESC
