# Explicação VAS Claro Fibra — setembro × outubro/2026

## 1. Escopo e critério

| Item | Definição usada |
|---|---|
| Produto Cognos | **CLARO FIBRA** (de-para `N5919189.BI_DIM_CONTACONTABIL_FIXA` → `PRODUTO_COGNOS`) |
| Tipo de produto | **NT** (VAS) |
| Competências | **2026-09-01** × **2026-10-01** |
| Valor de receita | `DSC_TIPO = 'Receita'` + `DSC_SUBTIPO = 'Bruta'` |
| Valor de desconto | `DSC_TIPO = 'Desconto'` + `DSC_SUBTIPO = 'Bruta'` |
| Cliente | `COD_OPERADORA` + `NUM_CONTRATO` |
| Segmento | `DSC_SEGMENTACAO`, com **CONS = CONSUMO** |

Base: `u92870757.BI_FP_RECEITA_FIXA`, cruzada com a conta contábil do de-para.

---

## 2. Os dois movimentos (visão que bate com o Tableau)

| Movimento | Setembro | Outubro | Variação |
|---|---:|---:|---:|
| **Receita / Bruta** | 382.125.502,48 | 386.925.177,61 | **+4.799.675,13** |
| **Desconto / Bruta** | −5.618.266,06 | −2.920.769,33 | **+2.697.496,73** |
| Imposto / Bruta | −11.248.035,04 | −11.496.531,12 | −248.496,08 |

Desconto é negativo: variação **positiva** de +2,70 mi significa **menos desconto concedido** (melhora o resultado).

**Conclusão de abertura:** o chefe precisa entender (1) por que a receita de VAS subiu ~4,8 mi e (2) por que o desconto de VAS caiu ~2,7 mi. Os dois estão confirmados na base Oracle alinhada ao Cognos/Tableau.

---

## 3. Movimento 1 — Aumento de receita (+4,80 mi)

### 3.1 Fechamento por tipo de contribuição

Fonte: `query 27.csv`. Soma = **+4.799.675,13**.

| Tipo | Variação | Interpretação |
|---|---:|---|
| **RECEITA_NOVA** | **+32.019.876,56** | Cliente sem aquele produto em set, com valor em out |
| **RECEITA_SUMIU** | **−27.041.979,94** | Cliente tinha o produto em set e zerou em out |
| AUMENTO | +7.103.382,98 | Já tinha o produto e o valor subiu |
| QUEDA | −8.242.589,21 | Já tinha o produto e o valor caiu |
| ESTORNO | +960.984,74 | Valor negativo em set que sumiu em out |
| **Líquido** | **+4.799.675,13** | |

**Justificativa:** o +4,8 mi **não** é só reajuste de preço. É o líquido de uma **rotação forte de catálogo**: entram ~32 mi de receita “nova” em produtos/clientes e saem ~27 mi de produtos que deixaram de faturar. Ticket em quem já tinha o mesmo produto (+7,1 mi) é menor que a queda no mesmo universo (−8,2 mi).

### 3.2 Concentração em Skeelo

Família Skeelo (nome contendo `SKEELO`): **~+2,39 mi** ≈ **50%** do líquido de receita.

Padrão típico de **migração de SKU**:

| Direção | Exemplos | Ordem de grandeza |
|---|---|---:|
| Sobe | `SKEELO AUDIOBOOK RED (V)`, `PREMIUM`, `RED (T)`, `RED 15/59/Z/14` | +0,7 a +1,7 mi cada um nos maiores |
| Cai | `PREMIUM REDUZIDO (C)/(E)/(B)`, `SKEELO` genérico, `RED PADRAO` | −0,9 a −1,7 mi cada um nos maiores |

Exemplo do maior negativo — `SKEELO AUDIOBOOK PREMIUM REDUZIDO (C)`:

- RECEITA_SUMIU: −2,10 mi (115.401 clientes)
- RECEITA_NOVA: +0,57 mi
- QUEDA / AUMENTO / ESTORNO: demais
- **Líquido do produto ≈ −1,74 mi**

Exemplo do maior positivo — `SKEELO AUDIOBOOK RED (V)`: **~+1,67 mi** líquidos.

**Justificativa:** o aumento de receita de VAS Fibra é, em grande parte, **troca dentro de Skeelo** — saída de ofertas “reduzido/padrão/genérico” e entrada em SKUs RED (V)/(T)/Premium e correlatos — e não um boom uniforme de todos os VAS.

---

## 4. Movimento 2 — Queda de desconto (+2,70 mi)

### 4.1 Fechamento por tipo de contribuição

Fonte: `query 26.csv`. Soma = **+2.697.496,73**.

| Tipo | Variação | Interpretação |
|---|---:|---|
| **DESCONTO_SUMIU** | **+4.228.370,91** | Tinha desconto em set, zero em out |
| DESCONTO_NOVO | −1.556.906,32 | Passou a ter desconto em out |
| DESCONTO_MENOR | +123.492,48 | Desconto ficou menos negativo |
| DESCONTO_MAIOR | −97.460,34 | Desconto ficou mais negativo |
| **Líquido** | **+2.697.496,73** | |

**Justificativa:** a queda de desconto é sobretudo **fim de concessão** (+4,23 mi de desconto que sumiu), parcialmente compensada por descontos novos (−1,56 mi). Não é um ajuste fino de percentual em massa; é saída de benefício.

### 4.2 Produtos que mais explicam o desconto

| Produto | Variação líquida de desconto |
|---|---:|
| SKEELO AUDIOBOOK RED (V) | +380.567,82 |
| SKEELO AUDIOBOOK PREMIUM REDUZIDO (E) | +243.155,86 |
| MINHA BANCA RESIDENCIAL REDUZIDO (E) | +238.494,52 |
| MCAFEE 3 DISPOSITIVOS REDUZIDO (E) | +169.682,22 |
| SKEELO AUDIOBOOK PREMIUM SOLAR | +162.996,73 |
| SKEELO AUDIOBOOK RED (T) | +156.453,92 |

Família Skeelo no desconto: **~+1,65 mi** (~61% do +2,70 mi).

Detalhe `SKEELO AUDIOBOOK RED (V)`:

- DESCONTO_SUMIU: **+529.868,60** em **87.771** clientes
- DESCONTO_NOVO: −157.229,34 em 24.580 clientes
- Líquido do produto ≈ **+381 mil**

**Justificativa:** o mesmo núcleo de produtos (Skeelo / “reduzido”) que migra na receita também perde desconto — coerente com **fim ou troca de oferta promocional**.

---

## 5. Por segmento (`DSC_SEGMENTACAO`)

CONS e CONSUMO unificados como **CONSUMO**. Totais batem com +4,80 mi e +2,70 mi.

### Receita / Bruta

| Segmento | Setembro | Outubro | Variação | % do +4,80 mi |
|---|---:|---:|---:|---:|
| **CONSUMO** | 342.289.995,71 | 346.601.774,03 | **+4.311.778,32** | **90%** |
| PE | 37.458.303,95 | 37.911.420,68 | +453.116,73 | 9% |
| ME | 1.728.071,17 | 1.755.824,56 | +27.753,39 | &lt;1% |
| GE | 649.131,65 | 656.158,34 | +7.026,69 | &lt;1% |

### Desconto / Bruta

| Segmento | Setembro | Outubro | Variação | % do +2,70 mi |
|---|---:|---:|---:|---:|
| **CONSUMO** | −4.876.314,10 | −2.550.673,87 | **+2.325.640,23** | **86%** |
| PE | −725.302,36 | −361.467,29 | +363.835,07 | 14% |
| ME | −12.882,76 | −6.265,30 | +6.617,46 | residual |
| GE | −3.766,84 | −2.362,87 | +1.403,97 | residual |

**Justificativa:** o fenômeno é **quase todo Consumo**. PE tem papel secundário; ME/GE não sustentam a narrativa.

---

## 6. Como os dois movimentos se encaixam

1. **Receita sobe (+4,8 mi)** porque há mais faturamento líquido de VAS, mas a mecânica dominante é **migração/rotação de produtos** (principalmente Skeelo), não um aumento homogêneo de ticket.
2. **Desconto cai (+2,7 mi no resultado)** porque **deixou de ser dado** em massa (`DESCONTO_SUMIU`), com Skeelo e linhas “reduzido” no topo.
3. Os dois apontam para a **mesma história de oferta**: saída de pacotes promocionais/reduzidos e recomposição do mix de VAS, concentrada em **Consumo / Claro Fibra**.
4. Efeitos colaterais (estorno, Unbilled) existem, mas **não** são o motor dos +4,8 / +2,7 mi de Bruta.

---

## 7. O que **não** explicar com estes números

- Receita “nova” **não** significa cliente 100% novo na base Claro; significa **aquele produto** zerado em set na chave cliente+produto (pode ter tido outro VAS).
- “Sem VAS” nas aberturas anteriores usava só **NT Receita/Bruta**; não inclui Unbilled/Imposto nem BL/TV.
- Unbilled e Imposto movem o total NT, mas o pedido do chefe está focado em **Receita Bruta** e **Desconto Bruta**.

---

## 8. Frase-síntese para o chefe

> No VAS Claro Fibra, de setembro para outubro, a Receita Bruta subiu **R$ 4,8 mi** e o Desconto Bruta caiu o equivalente a **R$ 2,7 mi** no resultado. Quase tudo está em **Consumo**. A receita sobe pelo líquido de uma grande troca de produtos (entra ~R$ 32 mi, sai ~R$ 27 mi), com Skeelo explicando cerca de metade; o desconto cai porque deixou de ser concedido (~R$ 4,2 mi de desconto sumindo), também puxado por Skeelo/reduzido. Em conjunto, indica **recomposição de oferta/mix de VAS**, não um único reajuste linear de preço.

---

## 9. Evidências (arquivos)

| Arquivo / consulta | Papel |
|---|---|
| Resumo Claro Fibra (Receita/Desconto/Imposto) | Bate Tableau (+4,80 / +2,70) |
| `query 26.csv` | Fechamento desconto |
| `query 27.csv` | Fechamento receita |
| Abertura por `DSC_SEGMENTACAO` | Consumo ~90% / ~86% |
| Scripts em `sql/` no branch `cursor/analise-aumento-vas-d2cc` | Reprodução Oracle |
