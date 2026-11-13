# Explicação VAS Claro Fibra — setembro × outubro/2026

## 1. Escopo e critério

| Item | Definição usada |
|---|---|
| Produto Cognos | **CLARO FIBRA** (`N5919189.BI_DIM_CONTACONTABIL_FIXA.PRODUTO_COGNOS`) |
| Tipo de produto | **NT** (VAS) |
| Competências | **2026-09-01** × **2026-10-01** |
| Receita | `DSC_TIPO = 'Receita'` + `DSC_SUBTIPO = 'Bruta'` |
| Desconto | `DSC_TIPO = 'Desconto'` + `DSC_SUBTIPO = 'Bruta'` |
| Cliente | `COD_OPERADORA` + `NUM_CONTRATO` |
| Segmento | `DSC_SEGMENTACAO`, com **CONS = CONSUMO** |

Base: `u92870757.BI_FP_RECEITA_FIXA` × de-para de conta contábil.

Dinâmica para o chefe explorar: rodar `sql/vas_dinamica_analitica.sql`, exportar e pivôtrar.

---

## 2. Os dois movimentos (bate com o Tableau)

| Movimento | Setembro | Outubro | Variação |
|---|---:|---:|---:|
| **Receita / Bruta** | 382.125.502,48 | 386.925.177,61 | **+4.799.675,13** |
| **Desconto / Bruta** | −5.618.266,06 | −2.920.769,33 | **+2.697.496,73** |

Desconto negativo: +2,70 mi = **menos desconto concedido**.

---

## 3. Movimento 1 — Receita +4,80 mi

### 3.1 Fechamento por tipo (`query 27`)

| Tipo | Variação | Interpretação |
|---|---:|---|
| **RECEITA_NOVA** | **+32.019.876,56** | Produto zerado em set, com valor em out |
| **RECEITA_SUMIU** | **−27.041.979,94** | Produto tinha valor em set e zerou |
| AUMENTO | +7.103.382,98 | Mesmo produto, valor maior |
| QUEDA | −8.242.589,21 | Mesmo produto, valor menor |
| ESTORNO | +960.984,74 | Negativo em set que sumiu |
| **Líquido** | **+4.799.675,13** | |

**Justificativa:** o +4,8 mi é líquido de **rotação de catálogo** (+32 mi entra / −27 mi sai), não só reajuste de preço.

### 3.2 O que é RECEITA_NOVA de verdade

`RECEITA_NOVA` **não** significa “cliente novo”. Significa **produto novo naquele cliente**.

Abertura do +32,02 mi:

| Situação do cliente em setembro | Clientes | Variação | % |
|---|---:|---:|---:|
| **Já tinha VAS em set** | 696.531 | **+20.513.786,01** | **64%** |
| **Sem VAS em set** | 445.704 | **+11.506.090,55** | **36%** |
| **Total** | | **+32.019.876,56** | 100% |

**Justificativa:**
- **64% (~+20,5 mi):** cliente antigo de VAS que **trocou/adicionou produto** (encaixa na migração Skeelo).
- **36% (~+11,5 mi):** cliente **sem Receita/Bruta NT Fibra em setembro** (adesão ao VAS nesse recorte, ou cliente que só aparece em out).

### 3.3 Concentração em Skeelo

Família Skeelo ≈ **+2,39 mi (~50% do líquido** de receita).

- Sobe: RED (V), Premium, RED (T), RED 15/59/Z/14…
- Cai: Premium Reduzido (C)/(E)/(B), Skeelo genérico, RED Padrão

→ migração de ofertas **reduzido/padrão** para SKUs **RED (V)/(T)/Premium**.

---

## 4. Movimento 2 — Desconto +2,70 mi (`query 26`)

| Tipo | Variação | Interpretação |
|---|---:|---|
| **DESCONTO_SUMIU** | **+4.228.370,91** | Tinha desconto em set, zero em out |
| DESCONTO_NOVO | −1.556.906,32 | Desconto novo em out |
| DESCONTO_MENOR | +123.492,48 | Desconto ficou menor |
| DESCONTO_MAIOR | −97.460,34 | Desconto ficou maior |
| **Líquido** | **+2.697.496,73** | |

Família Skeelo no desconto ≈ **+1,65 mi (~61%)**.  
Só `SKEELO AUDIOBOOK RED (V)`: +381 mil (87.771 clientes com desconto sumindo).

**Justificativa:** motor = **fim de concessão de desconto**, compatível com vencimento/troca de promoção (hipótese; falta vigência da oferta para cravar).

---

## 5. Por segmento

| Segmento | Receita | % do +4,8 | Desconto | % do +2,7 |
|---|---:|---:|---:|---:|
| **CONSUMO** | **+4.311.778** | **90%** | **+2.325.640** | **86%** |
| PE | +453.117 | 9% | +363.835 | 14% |
| ME | +27.753 | &lt;1% | +6.617 | residual |
| GE | +7.027 | &lt;1% | +1.404 | residual |

**Justificativa:** fenômeno **quase todo Consumo**.

---

## 6. Narrativa única (atualizada)

> No VAS Claro Fibra (set→out), Receita Bruta **+R$ 4,8 mi** e Desconto Bruta **+R$ 2,7 mi** no resultado, concentrados em **Consumo** (~90% / ~86%).
>
> A receita sobe pelo líquido de troca de produtos (+32 mi entra / −27 mi sai). Dos +32 mi de “receita nova”, **64% (~R$ 20,5 mi) são produto novo em cliente que já tinha VAS em setembro**; **36% (~R$ 11,5 mi) são cliente sem VAS Bruta em setembro**. Skeelo explica ~metade do líquido, com saída de reduzido/padrão e entrada em RED (V)/(T)/Premium.
>
> O desconto cai porque **deixou de ser concedido** (+R$ 4,2 mi sumindo), também puxado por Skeelo/reduzido — padrão compatível com fim de promoção, a confirmar com vigência da oferta.
>
> Em conjunto: **recomposição de oferta/mix de VAS em Consumo**, não um único reajuste linear de preço.

---

## 7. Dinâmica para o chefe

1. Rodar `sql/vas_dinamica_analitica.sql` no DBeaver.
2. Exportar CSV/Excel.
3. Criar Tabela Dinâmica / Tableau com:
   - Filtros: `DSC_SEGMENTACAO`, `DSC_TIPO`, `TIPO_CONTRIBUICAO`, `SITUACAO_CLIENTE_SET`, `DSC_PRODUTO`
   - Valor: `VARIACAO` (e opcionalmente `QTD_CLIENTES`)
4. Visões sugeridas:
   - Receita × Desconto (total)
   - Por segmento
   - Por tipo de contribuição
   - Em `RECEITA_NOVA`: quebrar por `SITUACAO_CLIENTE_SET`
   - Top produtos (filtro família Skeelo)

---

## 8. Limitações

- Critério = só NT Receita/Desconto **Bruta** Claro Fibra.
- “Sem VAS em set” = sem Receita/Bruta NT Fibra; pode ter Unbilled/Imposto/BL/TV.
- Hipótese de promoção vencida é **compatível** com os dados, não comprovada só com set×out.
