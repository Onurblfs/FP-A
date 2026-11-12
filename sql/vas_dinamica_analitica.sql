-- Base analitica de VAS Claro Fibra (Receita/Bruta + Desconto/Bruta)
-- para dinamica em Excel / Tableau / Power BI.
--
-- Uma linha = segmento + tipo (Receita/Desconto) + produto + artigo +
-- tipo de contribuicao + situacao do cliente em setembro.
--
-- No pivô, use:
--   Linhas/colunas: DSC_SEGMENTACAO, DSC_TIPO, TIPO_CONTRIBUICAO,
--                   SITUACAO_CLIENTE_SET, DSC_PRODUTO
--   Valores: SOMA(VARIACAO), SOMA(QTD_CLIENTES), SOMA(VAL_MES_*)
--
-- CONS e CONSUMO = CONSUMO.
-- Ajuste as datas em PARAMETROS. Exportar o resultado e plugar na dinamica.

WITH PARAMETROS AS (
    SELECT
        DATE '2026-09-01' AS MES_ANTERIOR,
        DATE '2026-10-01' AS MES_ATUAL,
        'CLARO FIBRA' AS FILTRO_PRODUTO_COGNOS
    FROM DUAL
),
BASE AS (
    SELECT
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        CASE
            WHEN T.DSC_SEGMENTACAO IN ('CONS', 'CONSUMO') THEN 'CONSUMO'
            ELSE T.DSC_SEGMENTACAO
        END AS DSC_SEGMENTACAO,
        T.DSC_TIPO,
        T.DSC_PRODUTO,
        T.DSC_ARTIGO,
        SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ANTERIOR
                 THEN T.VAL_CALCULADO ELSE 0 END) AS VAL_MES_ANTERIOR,
        SUM(CASE WHEN T.DAT_COMPETENCIA = P.MES_ATUAL
                 THEN T.VAL_CALCULADO ELSE 0 END) AS VAL_MES_ATUAL
    FROM u92870757.BI_FP_RECEITA_FIXA T
    JOIN N5919189.BI_DIM_CONTACONTABIL_FIXA D
      ON TRIM(TO_CHAR(D.CONTA_CONTABIL)) = TRIM(TO_CHAR(T.COD_CONTA_CONTABIL))
    CROSS JOIN PARAMETROS P
    WHERE T.DSC_TIPO_PRODUTO = 'NT'
      AND T.DSC_TIPO IN ('Receita', 'Desconto')
      AND T.DSC_SUBTIPO = 'Bruta'
      AND T.DAT_COMPETENCIA IN (P.MES_ANTERIOR, P.MES_ATUAL)
      AND D.PRODUTO_COGNOS = P.FILTRO_PRODUTO_COGNOS
    GROUP BY
        T.COD_OPERADORA,
        T.NUM_CONTRATO,
        CASE
            WHEN T.DSC_SEGMENTACAO IN ('CONS', 'CONSUMO') THEN 'CONSUMO'
            ELSE T.DSC_SEGMENTACAO
        END,
        T.DSC_TIPO,
        T.DSC_PRODUTO,
        T.DSC_ARTIGO
),
VAS_CLIENTE AS (
    -- VAS do cliente no mes anterior so em Receita/Bruta (para situar RECEITA_NOVA)
    SELECT
        COD_OPERADORA,
        NUM_CONTRATO,
        SUM(CASE WHEN DSC_TIPO = 'Receita' THEN VAL_MES_ANTERIOR ELSE 0 END)
            AS VAS_RECEITA_MES_ANTERIOR
    FROM BASE
    GROUP BY
        COD_OPERADORA,
        NUM_CONTRATO
),
POR_CLIENTE AS (
    SELECT
        B.DSC_SEGMENTACAO,
        B.DSC_TIPO,
        B.DSC_PRODUTO,
        B.DSC_ARTIGO,
        B.COD_OPERADORA,
        B.NUM_CONTRATO,
        B.VAL_MES_ANTERIOR,
        B.VAL_MES_ATUAL,
        B.VAL_MES_ATUAL - B.VAL_MES_ANTERIOR AS VARIACAO,
        CASE
            WHEN B.DSC_TIPO = 'Receita'
                 AND B.VAL_MES_ANTERIOR = 0 AND B.VAL_MES_ATUAL > 0
                THEN 'RECEITA_NOVA'
            WHEN B.DSC_TIPO = 'Receita'
                 AND B.VAL_MES_ANTERIOR > 0 AND B.VAL_MES_ATUAL = 0
                THEN 'RECEITA_SUMIU'
            WHEN B.DSC_TIPO = 'Receita'
                 AND B.VAL_MES_ANTERIOR < 0 AND B.VAL_MES_ATUAL = 0
                THEN 'ESTORNO'
            WHEN B.DSC_TIPO = 'Receita'
                 AND B.VAL_MES_ATUAL > B.VAL_MES_ANTERIOR
                THEN 'AUMENTO'
            WHEN B.DSC_TIPO = 'Receita'
                 AND B.VAL_MES_ATUAL < B.VAL_MES_ANTERIOR
                THEN 'QUEDA'
            WHEN B.DSC_TIPO = 'Desconto'
                 AND B.VAL_MES_ANTERIOR < 0 AND B.VAL_MES_ATUAL = 0
                THEN 'DESCONTO_SUMIU'
            WHEN B.DSC_TIPO = 'Desconto'
                 AND B.VAL_MES_ANTERIOR = 0 AND B.VAL_MES_ATUAL < 0
                THEN 'DESCONTO_NOVO'
            WHEN B.DSC_TIPO = 'Desconto'
                 AND B.VAL_MES_ATUAL > B.VAL_MES_ANTERIOR
                THEN 'DESCONTO_MENOR'
            WHEN B.DSC_TIPO = 'Desconto'
                 AND B.VAL_MES_ATUAL < B.VAL_MES_ANTERIOR
                THEN 'DESCONTO_MAIOR'
            ELSE 'SEM_VARIACAO'
        END AS TIPO_CONTRIBUICAO,
        CASE
            WHEN B.DSC_TIPO = 'Receita'
                 AND B.VAL_MES_ANTERIOR = 0 AND B.VAL_MES_ATUAL > 0
                 AND C.VAS_RECEITA_MES_ANTERIOR = 0
                THEN 'CLIENTE_SEM_VAS_EM_SET'
            WHEN B.DSC_TIPO = 'Receita'
                 AND B.VAL_MES_ANTERIOR = 0 AND B.VAL_MES_ATUAL > 0
                THEN 'CLIENTE_JA_TINHA_VAS_EM_SET'
            WHEN C.VAS_RECEITA_MES_ANTERIOR = 0
                THEN 'CLIENTE_SEM_VAS_EM_SET'
            ELSE 'CLIENTE_JA_TINHA_VAS_EM_SET'
        END AS SITUACAO_CLIENTE_SET
    FROM BASE B
    JOIN VAS_CLIENTE C
      ON C.COD_OPERADORA = B.COD_OPERADORA
     AND C.NUM_CONTRATO = B.NUM_CONTRATO
    WHERE B.VAL_MES_ATUAL <> B.VAL_MES_ANTERIOR
)
SELECT *
FROM (
    SELECT
        DSC_SEGMENTACAO,
        DSC_TIPO,
        DSC_PRODUTO,
        DSC_ARTIGO,
        TIPO_CONTRIBUICAO,
        SITUACAO_CLIENTE_SET,
        COUNT(*) AS QTD_CLIENTES,
        ROUND(SUM(VAL_MES_ANTERIOR), 2) AS VAL_MES_ANTERIOR,
        ROUND(SUM(VAL_MES_ATUAL), 2) AS VAL_MES_ATUAL,
        ROUND(SUM(VARIACAO), 2) AS VARIACAO
    FROM POR_CLIENTE
    GROUP BY
        DSC_SEGMENTACAO,
        DSC_TIPO,
        DSC_PRODUTO,
        DSC_ARTIGO,
        TIPO_CONTRIBUICAO,
        SITUACAO_CLIENTE_SET
) R
ORDER BY
    R.DSC_TIPO,
    ABS(R.VARIACAO) DESC
