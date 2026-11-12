-- Clientes por trás da variação de um produto de VAS.
--
-- Use para abrir o número agregado do passo 2 (ex.: ~1,5 mi do
-- SKEELO AUDIOBOOK RED (V)) e ver quanto cada cliente contribuiu.
--
-- Antes de executar, ajuste em PARAMETROS as duas datas e o FILTRO_PRODUTO
-- (nome completo do produto, ou 'SKEELO%' para todos os Skeelo).
--
-- Considera somente os clientes cujo VAS total aumentou (mesmo universo do
-- passo 2). TIPO_CONTRIBUICAO separa:
--   NOVO     = não tinha o produto no mês anterior
--   ESTORNO  = tinha valor negativo no mês anterior e zero no atual
--   AUMENTO  = já tinha e o valor subiu
--   QUEDA    = o valor caiu (aparece quando o cliente no total sobe, mas
--             este produto específico cai; comum em troca de produto)
--
-- A soma da coluna VARIACAO desta consulta deve bater com a VARIACAO do
-- produto no passo 2.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL,
        'SKEELO AUDIOBOOK RED (V)' AS FILTRO_PRODUTO
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
      AND T.DSC_TIPO = 'Receita'
      AND T.DSC_SUBTIPO = 'Bruta'
      AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
    GROUP BY
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        T.DSC_PRODUTO,
        T.DSC_ARTIGO
),
CLIENTES_COM_AUMENTO AS (
    SELECT
        COD_OPERADORA,
        NUM_CONTRATO
    FROM BASE
    GROUP BY
        COD_OPERADORA,
        NUM_CONTRATO
    HAVING SUM(VAL_MES_ATUAL) > SUM(VAL_MES_ANTERIOR)
)
SELECT
    B.COD_OPERADORA,
    B.NUM_CONTRATO,
    B.DSC_PRODUTO,
    B.DSC_ARTIGO,
    ROUND(B.VAL_MES_ANTERIOR, 2) AS VAL_MES_ANTERIOR,
    ROUND(B.VAL_MES_ATUAL, 2) AS VAL_MES_ATUAL,
    ROUND(B.VAL_MES_ATUAL - B.VAL_MES_ANTERIOR, 2) AS VARIACAO,
    CASE
        WHEN B.VAL_MES_ANTERIOR = 0 AND B.VAL_MES_ATUAL > 0 THEN 'NOVO'
        WHEN B.VAL_MES_ANTERIOR < 0 AND B.VAL_MES_ATUAL = 0 THEN 'ESTORNO'
        WHEN B.VAL_MES_ATUAL > B.VAL_MES_ANTERIOR THEN 'AUMENTO'
        WHEN B.VAL_MES_ATUAL < B.VAL_MES_ANTERIOR THEN 'QUEDA'
        ELSE 'SEM_VARIACAO'
    END AS TIPO_CONTRIBUICAO
FROM BASE B
JOIN CLIENTES_COM_AUMENTO C
  ON C.COD_OPERADORA = B.COD_OPERADORA
 AND C.NUM_CONTRATO = B.NUM_CONTRATO
CROSS JOIN PARAMETROS P
WHERE B.DSC_PRODUTO LIKE P.FILTRO_PRODUTO
  AND B.VAL_MES_ATUAL <> B.VAL_MES_ANTERIOR
ORDER BY VARIACAO DESC
