# Dicionário — análise VAS Claro Fibra

Termos usados nas queries, no fechamento e na dinâmica.  
Critério de valor, salvo indicação: **NT** + **Receita ou Desconto** + **Bruta** + **CLARO FIBRA**.

---

## 1. Dimensões de negócio

| Nome | O que é |
|---|---|
| **VAS / NT** | Value Added Service. Na base, `DSC_TIPO_PRODUTO = 'NT'`. |
| **CLARO FIBRA** | Classificação do produto Cognos no de-para `BI_DIM_CONTACONTABIL_FIXA` (`PRODUTO_COGNOS`). Filtra as contas contábeis da Fibra. |
| **Receita Bruta** | `DSC_TIPO = 'Receita'` e `DSC_SUBTIPO = 'Bruta'`. Valor faturado usado na análise de aumento. |
| **Desconto Bruta** | `DSC_TIPO = 'Desconto'` e `DSC_SUBTIPO = 'Bruta'`. Entra **negativo**. Variação positiva = menos desconto. |
| **Unbilled** | Lançamento a faturar / estorno contábil paralelo. **Não** entra no fechamento de Bruta. |
| **Imposto** | Tributos. Fora do foco receita/desconto Bruta. |
| **Cliente** | Chave `COD_OPERADORA` + `NUM_CONTRATO`. |
| **Produto** | `DSC_PRODUTO` (ex.: SKEELO AUDIOBOOK RED (V)). |
| **Artigo** | `DSC_ARTIGO` (ex.: VASSKEELORES). |
| **Segmento** | `DSC_SEGMENTACAO`. **CONS** e **CONSUMO** são tratados como o mesmo (**CONSUMO**). Demais: **PE**, **ME**, **GE**. |
| **Competência** | `DAT_COMPETENCIA` (mês de referência). Na análise: set/2026 × out/2026. |

---

## 2. Tipos de contribuição — Receita

Classificação **por cliente + produto (+ artigo)**, comparando valor de set com out.

| Nome | Regra | Em português |
|---|---|---|
| **RECEITA_NOVA** | Set = 0 e Out > 0 | O cliente **não tinha esse produto** (`DSC_PRODUTO`) em setembro e passou a ter em outubro. **Não** significa cliente novo na Claro. |
| **RECEITA_SUMIU** | Set > 0 e Out = 0 | Tinha o produto em setembro e **zerou** em outubro. |

**Atenção — mudança de nome:** se o `DSC_PRODUTO` mudar (rename/migração de SKU), o sistema trata como **RECEITA_SUMIU** no nome antigo + **RECEITA_NOVA** no nome novo, mesmo sendo o mesmo cliente. Isso entra no +32 mi / −27 mi. O `DSC_ARTIGO` às vezes é mais estável e ajuda a ver a família (ex.: VASSKEELORES).
| **AUMENTO** | Out > Set (e não é os casos acima) | Já tinha o produto e o valor **subiu**. |
| **QUEDA** | Out < Set (com Set ≥ 0) | Já tinha o produto e o valor **caiu**. |
| **ESTORNO** | Set < 0 e Out = 0 | Tinha valor **negativo** em setembro (crédito/estorno) e zerou. Aparece como variação positiva, mas não é venda nova. |
| **SEM_VARIACAO** | Set = Out | Sem mudança (em geral filtrado fora). |

---

## 3. Situação do cliente em setembro (só para contextualizar RECEITA_NOVA)

| Nome | Regra | Em português |
|---|---|---|
| **CLIENTE_JA_TINHA_VAS_EM_SET** | Soma de Receita/Bruta NT Fibra do cliente em set **≠ 0** | Cliente **já era de VAS** em setembro; em outubro entrou **outro produto** (ou o mesmo estava zerado). |
| **CLIENTE_SEM_VAS_EM_SET** | Soma de Receita/Bruta NT Fibra do cliente em set **= 0** | Cliente **sem VAS Bruta** em setembro neste recorte Fibra. Pode ser adesão ao VAS ou primeira aparição no recorte. |

No +32 mi de RECEITA_NOVA: **64%** já tinha VAS | **36%** sem VAS em set.

---

## 4. Tipos de contribuição — Desconto

Desconto é negativo. “Cair o desconto” = valor menos negativo = **variação positiva** no resultado.

| Nome | Regra | Em português |
|---|---|---|
| **DESCONTO_SUMIU** | Set < 0 e Out = 0 | Tinha desconto em setembro e **deixou de ter** em outubro. Principal motor da “queda de desconto”. |
| **DESCONTO_NOVO** | Set = 0 e Out < 0 | **Passou a ter** desconto em outubro. |
| **DESCONTO_MENOR** | Out > Set (ainda com desconto ou indo a zero parcial) | Continua com desconto, mas **menor** (menos negativo). |
| **DESCONTO_MAIOR** | Out < Set | Desconto **aumentou** (mais negativo). |
| **SEM_VARIACAO** | Set = Out | Sem mudança. |

---

## 5. Campos da dinâmica (`vas_dinamica_analitica`)

| Campo | Uso no pivô |
|---|---|
| `DSC_SEGMENTACAO` | Filtro/quebra por Consumo, PE, ME, GE |
| `DSC_TIPO` | Receita × Desconto |
| `DSC_PRODUTO` / `DSC_ARTIGO` | Produto e artigo |
| `TIPO_CONTRIBUICAO` | RECEITA_NOVA, DESCONTO_SUMIU, etc. |
| `SITUACAO_CLIENTE_SET` | Já tinha / sem VAS em setembro |
| `QTD_CLIENTES` | Quantidade de clientes na célula |
| `VAL_MES_ANTERIOR` | Valor em setembro |
| `VAL_MES_ATUAL` | Valor em outubro |
| `VARIACAO` | Out − Set (métrica principal) |

---

## 6. Frases curtas para o chefe

| Se ele perguntar… | Responda… |
|---|---|
| O que é RECEITA_NOVA? | Produto que o cliente não tinha em set; **64%** já era cliente de VAS. |
| O que é RECEITA_SUMIU? | Produto que o cliente tinha e zerou em out. |
| Por que desconto “sobe” no número? | Desconto é negativo; sumir desconto melhora o resultado (+). |
| O que é DESCONTO_SUMIU? | Cliente tinha desconto e perdeu. |
| O que é Consumo? | Segmento `DSC_SEGMENTACAO` (CONS = CONSUMO). |
| O que é Claro Fibra aqui? | Contas do de-para com `PRODUTO_COGNOS = 'CLARO FIBRA'`. |
