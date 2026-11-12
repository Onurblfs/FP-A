-- Passo 2: produtos de VAS que mais variaram entre os clientes com aumento.
--
-- Antes de executar:
--   1. Troque NOME_DA_TABELA pela tabela de origem.
--   2. Ajuste as duas datas em PARAMETROS (as mesmas do passo 1).
--
-- Usa os mesmos critérios do passo 1: cliente = COD_OPERADORA + NUM_CONTRATO,
-- VAS = DSC_TIPO_PRODUTO = 'NT', valor = Receita/Bruta.
--
-- Considera somente os clientes que aparecem no passo 1. Para medir a variação
-- de todos os clientes, remova o JOIN com CLIENTES_COM_AUMENTO.
--
-- A ordenação é pelo módulo da variação, então produtos que caíram também
-- aparecem no topo (por exemplo, quando o cliente troca um produto por outro).

WITH PARAMETROS AS (
    SELECT
        DATE '2026-07-01' AS MES_ANTERIOR,
        DATE '2026-08-01' AS MES_ATUAL
    FROM DUAL
),
BASE AS (
    SELECT
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        T.DSC_PRODUTO,
        SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                 THEN T.VAL_CALCULADO ELSE 0 END) AS VAL_MES_ANTERIOR,
        SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                 THEN T.VAL_CALCULADO ELSE 0 END) AS VAL_MES_ATUAL
    FROM NOME_DA_TABELA T
    CROSS JOIN PARAMETROS P
    WHERE T.DSC_TIPO_PRODUTO = 'NT'
      AND T.DSC_TIPO = 'Receita'
      AND T.DSC_SUBTIPO = 'Bruta'
      AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
    GROUP BY
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        T.DSC_PRODUTO
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
    B.DSC_PRODUTO,
    COUNT(*) AS QTD_CLIENTES,
    ROUND(SUM(B.VAL_MES_ANTERIOR), 2) AS VAL_MES_ANTERIOR,
    ROUND(SUM(B.VAL_MES_ATUAL), 2) AS VAL_MES_ATUAL,
    ROUND(SUM(B.VAL_MES_ATUAL) - SUM(B.VAL_MES_ANTERIOR), 2) AS VARIACAO
FROM BASE B
JOIN CLIENTES_COM_AUMENTO C
  ON C.COD_OPERADORA = B.COD_OPERADORA
 AND C.NUM_CONTRATO = B.NUM_CONTRATO
GROUP BY B.DSC_PRODUTO
ORDER BY ABS(SUM(B.VAL_MES_ATUAL) - SUM(B.VAL_MES_ANTERIOR)) DESC
