-- Clientes escolhidos: valor de cada produto deles, de um mês contra o outro.
--
-- Antes de executar, ajuste as duas datas em PARAMETROS e a lista em CLIENTES
-- (uma linha por cliente: COD_OPERADORA, NUM_CONTRATO). Para olhar um cliente
-- só, deixe apenas a primeira linha da lista.
--
-- Traz todos os produtos de cada cliente, não só VAS; a coluna DSC_TIPO_PRODUTO
-- mostra o tipo (NT = VAS). O valor é Receita/Bruta, como nas outras consultas.
--
-- Valor negativo é crédito ou estorno lançado naquele mês. Um produto com
-- valor negativo no mês anterior e zero no atual aparece com variação positiva
-- sem que o cliente tenha passado a pagar mais.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL
    FROM DUAL
),
CLIENTES AS (
    SELECT 3 AS COD_OPERADORA, 119759300 AS NUM_CONTRATO FROM DUAL
    UNION SELECT 121, 226665805 FROM DUAL
    UNION SELECT 765, 1171611 FROM DUAL
)
SELECT
    T.COD_OPERADORA,
    T.NUM_CONTRATO,
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
JOIN CLIENTES C
  ON C.COD_OPERADORA = T.COD_OPERADORA
 AND C.NUM_CONTRATO = T.NUM_CONTRATO
WHERE T.DSC_TIPO = 'Receita'
  AND T.DSC_SUBTIPO = 'Bruta'
  AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
GROUP BY
    T.COD_OPERADORA,
    T.NUM_CONTRATO,
    T.DSC_TIPO_PRODUTO,
    T.DSC_PRODUTO
ORDER BY
    T.COD_OPERADORA,
    T.NUM_CONTRATO,
    T.DSC_TIPO_PRODUTO,
    T.DSC_PRODUTO
