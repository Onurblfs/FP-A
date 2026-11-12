-- Um cliente só: valor de cada produto dele, de um mês contra o outro.
--
-- Antes de executar, ajuste em PARAMETROS as duas datas, o COD_OPERADORA e o
-- NUM_CONTRATO do cliente.
--
-- Traz todos os produtos do cliente, não só VAS; a coluna DSC_TIPO_PRODUTO
-- mostra o tipo (NT = VAS). O valor é Receita/Bruta, como nas outras consultas.
--
-- Valor negativo é crédito ou estorno lançado naquele mês. Um produto com
-- valor negativo no mês anterior e zero no atual aparece com variação positiva
-- sem que o cliente tenha passado a pagar mais.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL,
        97 AS COD_OPERADORA,
        5243762 AS NUM_CONTRATO
    FROM DUAL
)
SELECT
    T.DSC_TIPO_PRODUTO,
    T.DSC_PRODUTO,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ANTERIOR,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ATUAL,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE -T.VAL_CALCULADO END), 2) AS VARIACAO
FROM u92870757.BI_FP_RECEITA_FIXA T
CROSS JOIN PARAMETROS P
WHERE T.COD_OPERADORA = P.COD_OPERADORA
  AND T.NUM_CONTRATO = P.NUM_CONTRATO
  AND T.DSC_TIPO = 'Receita'
  AND T.DSC_SUBTIPO = 'Bruta'
  AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
GROUP BY
    T.DSC_TIPO_PRODUTO,
    T.DSC_PRODUTO
ORDER BY
    T.DSC_TIPO_PRODUTO,
    T.DSC_PRODUTO
