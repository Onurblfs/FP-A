-- Produtos de VAS cujo Desconto/Bruta mais variou entre os dois meses.
--
-- Desconto entra negativo. Queda de desconto = valor menos negativo =
-- VARIACAO positiva (melhora o total). Ajuste as datas em PARAMETROS.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL
    FROM DUAL
)
SELECT *
FROM (
    SELECT
        T.DSC_PRODUTO,
        T.DSC_ARTIGO,
        ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                       THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ANTERIOR,
        ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                       THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ATUAL,
        ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                       THEN T.VAL_CALCULADO ELSE -T.VAL_CALCULADO END), 2) AS VARIACAO
    FROM u92870757.BI_FP_RECEITA_FIXA T
    CROSS JOIN PARAMETROS P
    WHERE T.DSC_TIPO_PRODUTO = 'NT'
      AND T.DSC_TIPO = 'Desconto'
      AND T.DSC_SUBTIPO = 'Bruta'
      AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
    GROUP BY
        T.DSC_PRODUTO,
        T.DSC_ARTIGO
) R
ORDER BY ABS(R.VARIACAO) DESC
