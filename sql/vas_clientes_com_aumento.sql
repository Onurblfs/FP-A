-- Passo 1: clientes cujo VAS aumentou de um mês para o outro.
--
-- Antes de executar:
--   1. Troque NOME_DA_TABELA pela tabela de origem.
--   2. Ajuste as duas datas em PARAMETROS.
--
-- Cliente = COD_OPERADORA + NUM_CONTRATO. VAS = DSC_TIPO_PRODUTO = 'NT'.
--
-- O valor comparado é só Receita/Bruta. Somando todas as linhas o resultado é
-- sempre zero: cada lançamento Bruta tem um Unbilled de sinal oposto, e as
-- linhas de Imposto também se anulam.
--
-- TIPO_VARIACAO separa quem já tinha VAS no mês anterior (AUMENTO) de quem
-- não tinha nenhuma linha de VAS (NOVO).

WITH PARAMETROS AS (
    SELECT
        DATE '2026-07-01' AS MES_ANTERIOR,
        DATE '2026-08-01' AS MES_ATUAL
    FROM DUAL
)
SELECT
    T.COD_OPERADORA,
    T.NUM_CONTRATO,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ANTERIOR,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ATUAL,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE -T.VAL_CALCULADO END), 2) AS VARIACAO,
    CASE
        WHEN COUNT(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR THEN 1 END) = 0
        THEN 'NOVO'
        ELSE 'AUMENTO'
    END AS TIPO_VARIACAO
FROM NOME_DA_TABELA T
CROSS JOIN PARAMETROS P
WHERE T.DSC_TIPO_PRODUTO = 'NT'
  AND T.DSC_TIPO = 'Receita'
  AND T.DSC_SUBTIPO = 'Bruta'
  AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
GROUP BY
    T.COD_OPERADORA,
    T.NUM_CONTRATO
HAVING SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                THEN T.VAL_CALCULADO ELSE -T.VAL_CALCULADO END) > 0
ORDER BY VARIACAO DESC
