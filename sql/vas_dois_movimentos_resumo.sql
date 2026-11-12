-- Visão dos dois movimentos de NT: Receita/Bruta e Desconto/Bruta.
--
-- Espelha o pivot do Tableau (setembro contra outubro). Ajuste as datas
-- em PARAMETROS. Se no Tableau houver filtro de família (ex.: CLARO FIBRA)
-- e existir coluna equivalente na tabela, acrescente no WHERE.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL
    FROM DUAL
)
SELECT
    T.DSC_TIPO,
    T.DSC_SUBTIPO,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ANTERIOR,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ATUAL,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE -T.VAL_CALCULADO END), 2) AS VARIACAO
FROM u92870757.BI_FP_RECEITA_FIXA T
CROSS JOIN PARAMETROS P
WHERE T.DSC_TIPO_PRODUTO = 'NT'
  AND T.DSC_TIPO IN ('Receita', 'Desconto', 'Imposto')
  AND T.DSC_SUBTIPO IN ('Bruta', 'Unbilled', 'Cancelamento')
  AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
GROUP BY
    T.DSC_TIPO,
    T.DSC_SUBTIPO
ORDER BY
    T.DSC_TIPO,
    T.DSC_SUBTIPO
