-- Lista os valores de PRODUTO_COGNOS no de-para de conta contábil.
-- Use para confirmar o nome exato do filtro (ex.: 'CLARO FIBRA' vs 'Claro Fibra').

SELECT
    PRODUTO_COGNOS,
    COUNT(*) AS QTD_CONTAS
FROM N5919189.BI_DIM_CONTACONTABIL_FIXA
GROUP BY PRODUTO_COGNOS
ORDER BY PRODUTO_COGNOS
