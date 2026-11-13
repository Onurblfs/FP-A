-- Passo 3: valor de um produto de VAS por cliente, de um mês contra o outro.
--
-- Antes de executar, ajuste em PARAMETROS as duas datas e o FILTRO_PRODUTO.
-- O filtro usa LIKE: 'SKEELO%' traz todos os produtos que começam com SKEELO;
-- para um produto só, escreva o nome completo, sem o %.
--
-- Usa os mesmos critérios dos passos 1 e 2: cliente = COD_OPERADORA +
-- NUM_CONTRATO, VAS = DSC_TIPO_PRODUTO = 'NT', valor = Receita/Bruta.
--
-- Traz todos os clientes que tiveram o produto em pelo menos um dos dois meses,
-- inclusive os que caíram ou não variaram. O passo 2 considera só os clientes
-- cujo VAS total aumentou, então os totais daqui não batem com os de lá.
--
-- Um cliente que trocou de um produto para outro aparece em duas linhas: uma
-- com o produto antigo indo a zero e outra com o novo saindo de zero.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL,
        'SKEELO%' AS FILTRO_PRODUTO
    FROM DUAL
)
SELECT
    T.COD_OPERADORA,
    T.NUM_CONTRATO,
    T.DSC_PRODUTO,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ANTERIOR,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE 0 END), 2) AS VAL_MES_ATUAL,
    ROUND(SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                   THEN T.VAL_CALCULADO ELSE -T.VAL_CALCULADO END), 2) AS VARIACAO
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
ORDER BY VARIACAO DESC
