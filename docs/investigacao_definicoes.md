> Relatório de pesquisa de 08/11/2026 sobre as definições de caso. Só traz agregados e trechos dos dicionários.
> Aplicado em 08/11/2026: correção da chikungunya 2014–2016; padrão só de confirmados em raiva, Chagas e LV (critério do Ministério); serpentes sem as não peçonhentas. O resto está no `BACKLOG.md`.

# Investigação: definições de caso do VigiTrop

Data: 08/11/2026. Só pesquisa: nenhum arquivo do repositório foi alterado.

**Fontes.** Arquivos brutos do SINAN em `data/cache/downloads/ducklake/sinan/*.parquet`, lidos via `data/bronze/manifesto.csv`. Silver em `data/silver/casos/`. Dicionários em `Dicionarios/`, com o texto extraído página a página por `pdftotext`; as páginas citadas são as do PDF. As consultas foram feitas em DuckDB.

**Web.** Só funcionou a busca. `www.gov.br` e `repositorio.ufpa.br` estão bloqueados na rede desta sessão, então os números oficiais vêm dos trechos dos resultados de busca. As URLs estão listadas no fim. Os PDFs do Ministério não foram abertos.

---

## 0. Antes de tudo: o que há (e o que falta) em `Dicionarios/`

| Arquivo | Agravo no cabeçalho (p. 1) | Versão |
|---|---|---|
| `dic_raiva.pdf` | **"AGRAVO: ATENDIMENTO ANTI-RÁBICO"** | SINAN NET 5.0, revisado em dez/2014 |
| `dic_chagas.pdf` | "AGRAVO: DOENÇA DE CHAGAS" | revisado em jul/2010 |
| `dic_leishmaniose_visceral.pdf` | "AGRAVO: Leishmaniose Visceral" | revisado em jul/2010 |
| `dic_leishmaniose_cutanea.pdf` | "AGRAVO: LEISHIMANIOSE TEGUMENTAR AMERICANA" | revisado em jul/2010 |
| `dic_animais_peconhentospdf` | "AGRAVO: ACIDENTE ANIMAIS PEÇONHENTOS" | revisado em jul/2010 |
| `dic_hanseniase.pdf` | "AGRAVO: HANSENÍASE" | SINAN NET 5.0 |
| `dic_dengue.pdf` e `dic_chikungunya.pdf` | "DOENÇA: DENGUE e CHIKUNGUNYA" | **arquivos idênticos** (mesmo md5), SINAN Online v3.0, revisado em 21/10/2015 |

- **`dic_raiva.pdf` não é o dicionário de raiva humana (RAIV).** É o do Atendimento Antirrábico (ANTR). Os campos são `ANT_*`, `TRA_*`, `DOSES` etc., e não há `CLASSI_FIN`, `CRITERIO` nem `EVOLUCAO`. Por isso o BACKLOG diz que o código 8 "não aparece no dicionário de RAIV": o repositório simplesmente não tem esse dicionário. Falta obtê-lo (Portal Sinan).
- O dicionário de dengue/chik é o da ficha do SINAN Online de 2015. Ele **não cobre** a ficha de chikungunya do SINAN NET, usada em 2014-2016 (ver seção 2).
- A palavra "inconclusivo" só aparece nos dicionários como **resultado de exame**: Chagas p. 5-8 (sorologias); dengue/chik p. 5-7 ("3-Inconclusivo"). **Nenhum dicionário lista `CLASSI_FIN = 8`.**

---

## 1. `CLASSI_FIN = 8` ("inconclusivo")

### 1.1 O que os dicionários dizem

- **Chagas** (`dic_chagas.pdf`, p. 10):
  - campo 57, Classificação Final: "1-confirmado / 2-descartado", "CAMPO OBRIGATÓRIO quando o campo data de encerramento estiver preenchido";
  - campo 58, CRITERIO: "1-laboratório, 2-clínico-epidemiológico, 3-clínico";
  - campo 59, EVOLUCAO: "1 – vivo, 2 – óbito por chagas, 3 – óbito por outras causas, 9 – ignorado", "Campo habilitado se Classificação final=1,2 ou null".
- **LV** (`dic_leishmaniose_visceral.pdf`):
  - p. 6, campo 44: "1. Confirmado / 2. Descartado". Exame parasitológico ou imunológico positivo leva a "preencher automaticamente com 1 (confirmado)" (também na p. 4, campo 36);
  - p. 7, campo 45, CRITERIO: laboratorial ou clínico-epidemiológico;
  - p. 14, campo 53, EVOLUCAO: "1. Cura 2. Abandono 3. Óbito por LV 4. Óbito por outras causas 5. Transferência", "Campo habilitado se classificação final=1,2 ou null".
- **Dengue/chik** (`dic_dengue.pdf`, p. 14, campo 62): "5-Descartado, 10-Dengue, 11-Dengue com sinais de alarme, 12-Dengue grave, 13-Chikungunya". O código 8 não aparece. Na p. 14, campo 63, CRITERIO tem "3-Em investigação".
- **Raiva humana:** sem dicionário no repositório (ver seção 0).

Os dicionários de Chagas e LV só habilitam EVOLUCAO quando a classificação final é 1, 2 ou nula. O código 8 não está previsto na ficha. Isso combina com o que os dados mostram a seguir: um valor gravado pelo sistema, não pelo investigador.

### 1.2 A assinatura do código 8 nos dados (igual em todos os agravos)

| Agravo (período) | Inconclusivos | Sem CRITERIO | Sem EVOLUCAO | Encerrados ≥ 61 dias após a notificação | Entre 61 e 70 dias | Mediana (dias) | Confirmados encerrados ≥ 61 dias |
|---|---|---|---|---|---|---|---|
| Raiva (2007-2021) | 575 | 99,1% | (sem a coluna) | 98,3% | 69,4% | 66 | — |
| Chagas (2012-2025) | 6.364 | 97,9% | 96,2% | 99,4% | 81,9% | 64 | 14,3% |
| LV (2007-2025) | 6.188 | 95,0% | 96,8% | 99,7% | 76,0% | 65 | 17,6% |
| Dengue 2015 | 307.901 | 95,7% | — | 99,5% | 99,2% | **61** | 17,9% (código 10) |
| Dengue 2024 | 542.641 | 93,2% | — | 99,7% | 99,2% | **61** | 17,0% (código 10) |
| Chik 2015 | 17.980 | 97,9% | — | 99,9% | 67,6% | 66 | 26,8% (código 1) |

**Leitura:** o código 8 é o **encerramento por prazo**. São notificações que ninguém encerrou em 60 dias e que o sistema fechou como "inconclusivo", sem critério e sem evolução. Não é uma categoria clínica.

Na dengue isso é nítido: a mediana é de exatamente 61 dias. A Nota Técnica Conjunta 34/2026 do Ministério, no trecho da busca, cita "elevado número de casos encerrados automaticamente pelo sistema" de 2018 a 2025, junto com classificação final "vazia ou inconclusiva".

### 1.3 Raiva humana

Não existe coluna EVOLUCAO no RAIV, então o óbito foi medido por `DT_OBITO`.

| Ano | Notificações | 1 | 8 | 2 | Vazio | 1+8 (padrão atual) | 8 com óbito | Ministério |
|---|---|---|---|---|---|---|---|---|
| 2007 | 110 | 1 | 59 | 41 | 9 | 60 | 0 | |
| 2008 | 72 | 3 | 18 | 32 | 19 | 21 | 0 | |
| 2009 | 50 | 2 | 20 | 24 | 4 | 22 | 0 | |
| 2010 | 77 | 3 | 28 | 38 | 8 | 31 | 0 | |
| 2011 | 95 | 2 | 44 | 40 | 9 | 46 | 0 | |
| 2012 | 78 | 5 | 21 | 48 | 4 | 26 | 0 | |
| 2013 | 72 | 5 | 13 | 50 | 4 | 18 | 0 | |
| 2014 | 68 | 0 | 26 | 38 | 4 | 26 | 0 | |
| 2015 | 71 | 2 | 26 | 39 | 4 | 28 | 0 | |
| 2016 | 111 | 2 | 77 | 27 | 5 | 79 | 0 | |
| 2017 | 228 | 6 | 64 | 151 | 7 | 70 | 0 | |
| 2018 | 174 | 11 | 55 | 99 | 9 | 66 | 0 | **11** |
| 2019 | 127 | 1 | 32 | 79 | 15 | 33 | 0 | |
| 2020 | 148 | 2 | 41 | 98 | 7 | 43 | 0 | |
| 2021 | 198 | 1 | 51 | 140 | 6 | 52 | 0 | |
| 2022 | **7** | 2 | **0** | 5 | 0 | 2 | — | **5** |
| 2023 | 8 | 1 | 0 | 7 | 0 | 1 | — | ≥ 2 (até set/2023) |
| 2024 | 11 | 2 | 0 | 9 | 0 | 2 | — | |
| 2025* | 15 | 3 | 0 | 12 | 0 | 3 | — | |

\* preliminar.

**O que os 575 inconclusivos de 2007-2021 têm (e não têm):**
- **nenhum tem data de óbito**, numa doença com letalidade de cerca de 100%. Dos 46 confirmados do mesmo período, 40 têm data de óbito;
- só 6 têm algum sinal clássico (hidrofobia, aerofobia, paralisia, agressividade, disfagia). Entre os confirmados são 40 de 46;
- **nenhum** tem exame laboratorial positivo;
- 247 registram mordedura, arranhão ou lambedura, e 149 receberam tratamento antirrábico.

O perfil é de exposição a animal (atendimento antirrábico), não de doença.

**Comparação com o Ministério:**
- A soma dos confirmados de 2010 a 2021 dá **40**. Um estudo citado na busca traz exatamente 40 casos nesse período.
- Em 2018 são 11, como o Ministério divulga.
- Em 2022 o arquivo tem só 2 confirmados. O Ministério conta 5, segundo o Correio Braziliense.

**Quebra de série em 2022:** o arquivo cai de cerca de 150-230 notificações por ano para 7-15, e o código 8 some. Pela regra 1+8, a série despenca de 52 (2021) para 2 (2022) por puro artefato. A partir de 2022 o arquivo também parece incompleto: 2 de 5 casos em 2022.

### 1.4 Doença de Chagas aguda

| Ano | Notificações | 1 | 2 | 8 | Vazio | 1+8 | 1+8 ÷ 1 |
|---|---|---|---|---|---|---|---|
| 2007-2011 | 156 / 104 / 220 / 130 / 190 | = notificações | 0 | 0 | 0 | = 1 | 1,00 |
| 2012 | 4.014 | 189 | 3.231 | 534 | 60 | 723 | 3,83 |
| 2013 | 3.655 | 163 | 3.039 | 302 | 151 | 465 | 2,85 |
| 2014 | 3.830 | 196 | 3.271 | 269 | 94 | 465 | 2,37 |
| 2015 | 4.225 | 268 | 3.616 | 227 | 114 | 495 | 1,85 |
| 2016 | 4.190 | 378 | 3.376 | 314 | 122 | 692 | 1,83 |
| 2017 | 3.741 | 340 | 3.116 | 199 | 86 | 539 | 1,59 |
| 2018 | 4.685 | 380 | 3.726 | 446 | 133 | 826 | 2,17 |
| 2019 | 4.482 | 384 | 3.525 | 450 | 123 | 834 | 2,17 |
| 2020 | 2.602 | 180 | 2.081 | 275 | 66 | 455 | 2,53 |
| 2021 | 3.563 | 328 | 2.844 | 329 | 62 | 657 | 2,00 |
| 2022 | 5.194 | 413 | 4.191 | 485 | 105 | 898 | 2,17 |
| 2023* | 6.253 | 541 | 4.817 | 731 | 164 | 1.272 | 2,35 |
| 2024* | 6.520 | 547 | 5.118 | 692 | 163 | 1.239 | 2,27 |
| 2025* | 7.537 | 626 | 5.562 | 1.111 | 238 | 1.737 | 2,77 |

\* preliminar.

**Quebra de série em 2012.** Até 2011 o arquivo só traz confirmados. Com "só confirmados" a série é contínua (190 em 2011, 189 em 2012). Com 1+8 ela salta de 190 para 723 (×3,8) só porque o conteúdo do arquivo mudou.

**Geografia (2012-2025, por UF de residência):**
- 82% dos confirmados são do **Pará** (4.066 de 4.933): transmissão oral na Amazônia.
- Os inconclusivos se espalham por PA (1.371), BA (1.033), **RN (970)**, MG (763), CE (376), PB (257), GO (228) e RS (200).
- Em RN, MG e BA há, respectivamente, 17, 3 e 20 confirmados contra 970, 763 e 1.033 inconclusivos. Com 1+8, esses estados aparecem com Chagas aguda que praticamente não existe lá.

**Perfil dos inconclusivos:**
- idade média de 40,4 anos (confirmados: 33,3);
- febre em 10% (confirmados: 91%);
- parasitológico positivo em 0,3% (confirmados: 57%).

O perfil é de Chagas crônica ou suspeita não investigada, notificada na ficha de forma aguda.

**Literatura:** os confirmados do Pará batem com estudos baseados no SINAN: **1.517** em 2010-2017 contra 1.515 no estudo, e **1.394** em 2015-2019 contra 1.394. A literatura conta só `CLASSI_FIN = 1`.

CRITERIO dos inconclusivos: 106 laboratório, 25 clínico-epidemiológico, 4 clínico, 6.229 vazios. EVOLUCAO: 201 vivos, **1 óbito por Chagas**, 7 óbitos por outras causas, 35 ignorados, 6.120 vazios.

### 1.5 Leishmaniose visceral

| Ano | 1 | 8 | 1+8 | 8 como % de 1+8 |
|---|---|---|---|---|
| 2007 | 3.565 | 349 | 3.914 | 8,9 |
| 2010 | 3.704 | 257 | 3.961 | 6,5 |
| 2015 | 3.558 | 297 | 3.855 | 7,7 |
| 2018 | 3.851 | 319 | 4.170 | 7,6 |
| 2019 | 2.827 | 318 | 3.145 | 10,1 |
| 2020 | 2.202 | 286 | 2.488 | 11,5 |
| 2021 | 1.936 | 250 | 2.186 | 11,4 |
| 2022 | 1.983 | 216 | 2.199 | 9,8 |
| 2023 | 1.720 | 317 | 2.037 | 15,6 |
| 2024 | 1.459 | 298 | 1.757 | 17,0 |
| 2025 | 1.612 | 450 | 2.062 | 21,8 |

De 2007 a 2018 o peso fica entre 6% e 10%. Desde 2023 **o peso cresce (16-22%)**, o que suaviza artificialmente a queda recente da LV.

Inconclusivos (2007-2025, 6.188):
- 10 óbitos por LV (0,16%), contra 4.190 entre os 58.794 confirmados (7,1%);
- algum exame positivo (parasitológico, IFI ou outro) em 167 (2,7%), contra 84,8% dos confirmados;
- 92% sem parasitológico nem IFI realizado.

Pela regra do dicionário, um exame positivo já preenche a classificação com 1. Os inconclusivos são suspeitos sem exame, fechados por prazo.

Os indicadores do Grupo Técnico de Leishmanioses usam "casos novos confirmados". A informação vem de uma fonte secundária na busca e não foi verificada no original.

### 1.6 Dengue e chikungunya (comparação)

- **Dengue:** o código 8 pesa de 8% a 31% por ano (2007: 26,1%; 2012: 30,2%; 2017: 30,8%; 2022: 10,6%; 2024: 8,3%), com a mesma assinatura de 61 dias. Aqui ele **entra legitimamente**: o Ministério define "caso provável" como notificados menos descartados, e o padrão do app (`provavel`) já faz isso. Os arquivos de dengue não trazem `CLASSI_FIN = 5`.
- **Chikungunya:** o código 8 só existe em 2014-2016 (codificação antiga, ver seção 2). De 2017 em diante há menos de 15 por ano; os casos em aberto ficam com `CLASSI_FIN` vazio (16-32 mil por ano). Achado lateral: há lixo em `CLASSI_FIN` no CHIKBR21 (`'!ö'`, `'H0'`, um caractere invisível).

### 1.7 Argumentos

**A favor de manter 1+8 (padrão atual):**
- Reproduz o TCC (a validação passa).
- Dá mais sensibilidade: há alguns casos reais não encerrados. Na LV, 167 inconclusivos com exame positivo e 10 óbitos por LV; na Chagas, 99 com IgM positiva e 20 com parasitológico positivo.
- Combina com a lógica de "caso provável" das arboviroses.

**Contra:**
- O código 8 não é classificação clínica nem está em nenhum dicionário. É o fechamento automático por prazo: sem critério, sem evolução, encerrado com 61-70 dias.
- **Raiva:** 0 óbitos em 575 inconclusivos de uma doença quase 100% letal. O Ministério conta só confirmados (2018: 11; 2010-2021: 40). Pela regra 1+8 os números ficam de 6 vezes (2018) a 60 vezes (2007) maiores, e em 2014 há 26 casos contra 0 confirmados. Em 2022 o código some e a série quebra.
- **Chagas:** quebra de série em 2011/2012, geografia distorcida (RN, MG, BA) e literatura baseada em confirmados.
- **LV:** o peso crescente do código 8 distorce a tendência recente, e o indicador oficial usa confirmados.
- Para raiva, Chagas e LV o Ministério não publica "casos prováveis". Esse conceito é próprio das arboviroses.

**Recomendação:**
- Padrão = **só confirmados** (`CLASSI_FIN = '1'`) para raiva humana, Chagas aguda e LV.
- Manter `confirmado_ou_inconclusivo` como alternativa ou legado.
- Na raiva, mostrar contagem, não taxa, e avisar que os arquivos a partir de 2022 parecem incompletos (2 de 5 casos em 2022).
- Levar à orientadora com a tabela 1.2 (assinatura do encerramento automático) e o caso da raiva como argumento principal.
- Obter o dicionário RAIV de verdade.

---

## 2. Chikungunya 2015 (e 2014 e 2016)

**O que o dicionário cobre.** O dicionário do repositório é o da ficha única dengue/chik do SINAN Online (2015), com códigos 5 e 10-13 (p. 14). Ele não descreve a ficha de chikungunya do SINAN NET, usada antes. Não há dicionário da época no repositório.

**Duas codificações convivendo** (`TP_SISTEMA`: vazio ou 1 = SINAN NET; 2 = SINAN Online):

| Arquivo | TP_SISTEMA | Notificações | 1 | 2 | 8 | 13 | 5 | Vazio |
|---|---|---|---|---|---|---|---|---|
| 2014 | vazio ou 1 | 4.606 | 2.839 | 1.421 | 274 | 1 | 4 | 67 |
| 2014 | 2 | 16 | 0 | 0 | 0 | 9 | 5 | 2 |
| 2015 | 1 | 50.660 | 17.658 | 13.336 | 17.980 | 180 | 381 | 1.125 |
| 2015 | 2 | 1.682 | 3 | 2 | 0 | 485 | 794 | 398 |
| **2016** | **vazio** | **148.075** | **68.702** | **30.880** | **36.200** | 3.892 | 3.714 | 4.687 |
| 2016 | 2 | 162.671 | 182 | 202 | 259 | 84.796 | 41.082 | 36.149 |
| 2017 | 2 e vazio | 244.070 | 12 | 10 | 14 | 164.480 | 58.466 | 21.088 |

**O que os códigos antigos significam** (deduzido dos dados, sem dicionário):
- **1 = confirmado:** CRITERIO laboratorial ou clínico-epidemiológico; em 2016, 196 sorologias ou PCR reagentes contra 34 não reagentes.
- **2 = descartado:** em 2016, 12 reagentes contra **380 não reagentes**. O código 5 (descartado do SINAN Online) mostra o mesmo padrão: 240 contra 10.327.
- **8 = inconclusivo:** encerramento por prazo, com 97,9% sem critério e 99,9% encerrados com 61 dias ou mais.

Em 2015 os campos de laboratório do SINAN NET vêm vazios, então a leitura se apoia em 2016 e no critério.

**Importante:** o problema **não é só de 2015.** Em 2016, metade do arquivo (48%) ainda usa a codificação antiga, e o `confirmado` atual (`= '13'`) perde 68.884 confirmados.

**Regras equivalentes** (valem para todos os anos, porque depois de 2016 os códigos 1 e 2 quase não aparecem):
- confirmado: `CLASSI_FIN IN ('1','13')`
- provável: `CLASSI_FIN IS NULL OR CLASSI_FIN NOT IN ('2','5','10','11','12')`

| Ano | Confirmados (atual) | Confirmados (proposto) | Prováveis (atual) | Prováveis (proposto) | Ministério (prováveis) |
|---|---|---|---|---|---|
| 2014 | 10 | 2.849 | 4.613 | 3.192 | |
| **2015** | 665 (0,33) | **18.326 (9,05)** | 51.167 (25,28) | **37.829 (18,69)** | **38.332 (18,7)** |
| 2016 | 88.688 (43,5) | 157.572 (77,29) | 265.949 | 234.867 | 271.824, depois 277.882 |
| 2017 | 164.480 | 164.492 | 185.604 | 185.594 | **185.593** |

Entre parênteses, a taxa por 100 mil habitantes.

**Leituras da tabela:**
- O "provável" atual de 2015 conta como prováveis 13.338 descartados (código 2) e fica 33% acima do Ministério. O proposto fica a −1,3%.
- Em 2017 o proposto bate com o Ministério com diferença de 1 caso.
- 2016 não serve de referência limpa. O Ministério publicou 271.824 e depois 277.882, valores acima até do "provável" atual. O CHIKBR16 foi revisado em 20/05/2026. Vale conferir no TabNet.

**Comparação com o TCC:**
- **2015:** a taxa 16,03 equivale a cerca de 32.445 casos (população de 202.403.642). Nenhuma combinação reproduz esse número no arquivo atual. Testei:
  - 1+13 (18.326);
  - 1+8+13 (36.306);
  - não descartados (37.829);
  - 1+2+13 (31.664);
  - filtros de residência e autoctonia.

  O valor fica entre "confirmado" e "provável". O CHIKBR15 foi revisado em 26/05/2026, depois do TCC.
- **2016:** a taxa 78,06 equivale a cerca de 159.142 casos, a −1% de **1+13** (157.572; 77,29). Ou seja, o TCC já somava os confirmados das duas codificações em 2016. A `legado_tcc` atual (`= '13'`) dá 43,5 e não reproduz o TCC.

**Recomendação:**
- Trocar as regras de chik para as equivalentes acima (`confirmado`: 1 ou 13; `provavel`: excluir 2 e 5).
- Trocar a `legado_tcc` para `CLASSI_FIN IN ('1','13')`, que passa a bater em 2016 e 2017+.
- Marcar 2015 como "não reproduzível".
- Registrar no YAML que 1/2/8 é a codificação do SINAN NET (2014-2016).

---

## 3. Serpentes (`TP_ACIDENT = '1'`)

**Dicionário** (`dic_animais_peconhentospdf`, revisado em jul/2010):
- p. 6, campo 45, TP_ACIDENT: "1 – Serpente, 2 – Aranha, 3 – Escorpião, 4 – Lagarta, 5 – Abelha, 6 – Outros, 9 – Ignorado".
- p. 7, campo 46, ANI_SERPEN: "1 – Botrópico, 2 – Crotálico, 3 – Elapídico, 4 – Laquético, **5 – Serpente não peçonhenta**, **9 – Ignorado**". A descrição diz "Informar o tipo de acidente ofídico conforme as manifestações clínicas do envenenamento" e "Campo Obrigatório se 45-Campo Tipo de Acidente = 1 (serpente)".
- p. 7, campo 49, TRA_CLASSI: 1 leve, 2 moderado, 3 grave, 9 ignorado.
- p. 12-13: críticas que pedem confirmação quando o soro aplicado não combina com o tipo de acidente.

Na prática **não há `ANI_SERPEN` vazio** (0 linhas), porque o campo é obrigatório.

| Ano | Serpentes | 1-4 (TCC) | 5 | % 5 | 9 | % 9 | Sem o 5 (1-4 + 9) |
|---|---|---|---|---|---|---|---|
| 2007 | 26.886 | 22.294 | 1.019 | 3,8 | 3.573 | 13,3 | 25.867 |
| 2010 | 30.009 | 25.495 | 1.196 | 4,0 | 3.318 | 11,1 | 28.813 |
| 2013 | 27.906 | 23.287 | 1.360 | 4,9 | 3.259 | 11,7 | 26.546 |
| 2015 | 27.858 | 23.077 | 1.501 | 5,4 | 3.280 | 11,8 | 26.357 |
| 2017 | 30.094 | 24.701 | 1.980 | 6,6 | 3.413 | 11,3 | 28.114 |
| 2019 | 35.071 | 28.082 | 2.682 | 7,6 | 4.307 | 12,3 | 32.389 |
| 2020 | 33.285 | 27.016 | 2.389 | 7,2 | 3.880 | 11,7 | 30.896 |
| 2022 | 32.112 | 25.617 | 2.259 | 7,0 | 4.236 | 13,2 | 29.853 |
| 2023* | 33.659 | 26.105 | 3.041 | 9,0 | 4.513 | 13,4 | 30.618 |
| 2024* | 32.864 | 25.113 | 3.215 | 9,8 | 4.536 | 13,8 | 29.649 |
| 2025* | 32.637 | 24.436 | 3.455 | 10,6 | 4.746 | 14,5 | 29.182 |

\* preliminar. Todos os anos de 2007 a 2026 estão na consulta; o padrão é o mesmo.

**Perfil clínico (2007-2026):**

| Tipo | n | Recebeu soro | Leve | Moderado ou grave | Óbitos pelo agravo |
|---|---|---|---|---|---|
| 1-4 (peçonhenta conhecida) | 488.120 | 89,3% | 48,3% | 46,7% | 2.253 |
| 5 (não peçonhenta) | 38.710 | **5,7%** | **91,0%** | 4,8% | 29 |
| 9 (ignorado) | 74.302 | **40,8%** | 62,1% | **24,2%** | **223** |

**Tendência de 2007 a 2025:**

| Definição | Variação |
|---|---|
| Todas as serpentes (padrão atual) | +21,4% |
| Sem as não peçonhentas | +12,8% |
| Só 1-4 | +9,6% |

O peso das não peçonhentas triplicou (de 3,8% para 10,6%). Incluí-las cria uma alta artificial.

**Recomendação:**
- Padrão = **`ANI_SERPEN <> '5'`**: entram 1-4 e 9.
  - O agravo da OMS é "snakebite envenoming", ou seja, o envenenamento.
  - O código 5 não é envenenamento (5,7% com soro, 91% leves).
  - O 9 contém muitos envenenamentos reais de gênero não identificado (41% com soro, 223 óbitos). Tirá-lo subestimaria a carga.
- Manter `legado_tcc` (só 1-4) e "todas" como alternativas.
- Texto do app: "acidentes por serpente, exceto os com serpente não peçonhenta; inclui os de tipo ignorado".

---

## 4. Transferências nas leishmanioses

**Dicionários:**
- **LV** (`dic_leishmaniose_visceral.pdf`):
  - p. 4, campo 37, ENTRADA: "1. Caso novo 2. Recidiva 3. Transferência 9. Ignorado", "Campo obrigatório";
  - p. 14, campo 53, EVOLUCAO: "5. Transferência", que é a saída na unidade de origem.
- **LTA** (`dic_leishmaniose_cutanea.pdf`):
  - p. 4, campo 39, CLA_TIPO_N: "1 – Caso Novo 2 – Recidiva 3 – Transferência 9 – Ignorado";
  - p. 10, campo 56, EVOLUCAO: "5 Transferência, 6 – Mudança de diagnóstico".
  - Ainda na p. 10, a "Transferência vertical da investigação" (`NU_LOTE_I`) trata do fluxo de dados entre níveis do sistema, não do paciente.
- **Nenhum dicionário diz como contar casos ou deduplicar.** `NDUPLIC_N` está vazio em 99% das linhas da LV.

**Peso das transferências:**

| Ano | LV: 1+8 | LV: transferências em 1+8 | % | LV: transferências em 1 | LTA: notificações | LTA: transferências | % | LTA: EVOLUCAO 6 |
|---|---|---|---|---|---|---|---|---|
| 2007 | 3.914 | 39 | 1,0 | 38 | 22.645 | 63 | 0,3 | 214 |
| 2010 | 3.961 | 51 | 1,3 | 46 | 23.615 | 123 | 0,5 | 220 |
| 2014 | 4.101 | 106 | 2,6 | 104 | 22.031 | 152 | 0,7 | 219 |
| 2015 | 3.855 | 70 | 1,8 | 69 | 20.975 | 124 | 0,6 | 243 |
| 2018 | 4.170 | 51 | 1,2 | 51 | 17.950 | 113 | 0,6 | 307 |
| 2020 | 2.488 | 24 | 1,0 | 19 | 17.772 | 106 | 0,6 | 172 |
| 2022 | 2.199 | 41 | 1,9 | 38 | 14.305 | 73 | 0,5 | 249 |
| 2023 | 2.037 | 44 | 2,2 | 32 | 14.433 | 88 | 0,6 | 369 |
| 2024 | 1.757 | 33 | 1,9 | 24 | 11.150 | 72 | 0,6 | 318 |
| 2025 | 2.062 | 55 | 2,7 | 47 | 11.299 | 59 | 0,5 | 335 |

**Há contagem dupla?** Os dados públicos não têm identificador do paciente, então testei pares prováveis e comparei com a taxa de coincidência dos casos novos.

- **LV**, chave: ano de nascimento + sexo + data dos primeiros sintomas + UF de residência.
  - As transferências têm par em **4,0%**, contra **3,3%** dos casos novos.
  - Pares com uma "saída por transferência" (EVOLUCAO 5): 0,6% contra 0,4%.
  - **Não há excesso detectável.** O intervalo entre sintomas e notificação das transferências é normal (mediana de 28 dias, contra 22 dos casos novos). Elas são notificadas fora do município de residência com mais frequência (55% contra 40%), o que é coerente com encaminhamento a um centro de referência.
- **LTA**, chave: ano de nascimento + sexo + município de residência, com notificação até 365 dias antes ou depois.
  - Pares com EVOLUCAO 5: **7,0%** das transferências (125 registros) contra 1,1% dos casos novos.
  - Pela mesma data de diagnóstico: 3,5% contra 1,4%.
  - Há excesso, mas pequeno: cerca de 100 duplicatas prováveis em 19 anos, uns 5 por ano, menos de 0,05% da contagem.

**Achado lateral (LTA):** EVOLUCAO 6, "mudança de diagnóstico", soma de 170 a 370 registros por ano (1-3%). Ou seja, não é LTA, e hoje entra na contagem (`confirmado: TRUE`).

**Recomendação:**
- **Excluir as transferências** (`ENTRADA <> '3'` na LV; `CLA_TIPO_N <> '3'` na LTA). O impacto é pequeno (LV: −1% a −3%; LTA: −0,5%), mas alinha com o indicador de "casos novos" e elimina a parte mensurável de duplicidade na LTA.
- **Excluir também LTA com `EVOLUCAO = '6'`** (mudança de diagnóstico).
- Para decidir à parte: as **recidivas** (LV: 80-260 por ano, 2-12% dos confirmados e crescendo; LTA: 750-1.300 por ano, 5-7%). O indicador estrito de "casos novos" também as tiraria.

---

## 5. Ano de referência

**Como o DataSUS recorta os arquivos:**
- **DENG e CHIK:** pelo **ano epidemiológico dos primeiros sintomas**. Em 100% das linhas, o ano de `SEM_PRI` é igual ao ano do arquivo; `NU_ANO` difere em 22.608 linhas da dengue. Por exemplo, o DENGBR25 traz cerca de 7 mil notificações de 2026 com sintomas em 2025.
- **HANS, LEIV, LTAN, CHAG, RAIV, ANIM e ESQU:** pelo **NU_ANO** (99,9% a 100%).

A silver e o gold contam por `NU_ANO` em todos os agravos.

**Dengue (casos prováveis), por três referências:**

| Ano | NU_ANO (atual) | Arquivo = ano epidemiológico de SEM_PRI | Ano civil de DT_SIN_PRI | Arquivo vs NU_ANO | Ano civil vs NU_ANO |
|---|---|---|---|---|---|
| 2010 | 1.005.504 | 1.004.314 | 1.004.740 | −0,12% | −0,08% |
| 2015 | 1.620.808 | 1.623.172 | 1.622.106 | +0,15% | +0,08% |
| 2016 | 1.453.862 | 1.450.084 | 1.451.699 | −0,26% | −0,15% |
| 2019 | 1.546.528 | 1.546.252 | 1.548.076 | −0,02% | +0,10% |
| 2023 | 1.645.562 | 1.645.956 | 1.651.194 | +0,02% | +0,34% |
| 2024 | 6.567.126 | 6.564.924 | 6.569.236 | −0,03% | +0,03% |
| 2025 | 1.634.352 | 1.643.215 | 1.630.518 | **+0,54%** | −0,23% |
| 2026* | 477.509 | 470.451 | 473.598 | **−1,48%** | −0,82% |

\* preliminar. De 2007 a 2024 a diferença fica sempre em ±0,6%.

**Hanseníase (casos novos), NU_ANO vs ano de DT_DIAG:**

| Ano | NU_ANO (atual) | DT_DIAG | Diferença | Ministério |
|---|---|---|---|---|
| 2007 | 40.805 | 41.270 | +1,1% | |
| 2010 | 36.075 | 35.896 | −0,5% | |
| 2015 | 29.218 | 29.078 | −0,5% | |
| 2019 | 28.337 | 28.071 | −0,9% | |
| 2020 | 18.045 | 18.049 | 0,0% | |
| 2022 | 19.716 | 19.662 | −0,3% | |
| 2023 | 22.727 | 22.786 | +0,3% | **22.773** |
| 2024* | 22.194 | 22.228 | +0,2% | **22.129** |
| 2025* | 23.361 | 23.112 | −1,1% | |
| 2026* | 14.079 | 13.396 | −4,9% | |
| 2015-2024 | 240.200 | 239.558 | | **238.781** |

\* preliminar.

**Leituras:**
- O diagnóstico nunca é posterior à notificação. Entre 650 e 1.600 casos por ano são notificados com diagnóstico em ano anterior.
- 1.891 casos têm DT_DIAG antes de 2007 (alguns desde 1990) e sairiam da série.
- As duas referências ficam perto do Ministério. DT_DIAG fica um pouco mais perto: +0,3% contra +0,6% em 2015-2024.
- No último ano (preliminar), DT_DIAG sai menor, porque os diagnósticos do fim do ano ainda não foram notificados.

**Recomendação:** o efeito é pequeno (menos de 1% nos anos fechados), então a prioridade é baixa.
- **Dengue e chik:** usar o ano epidemiológico de `SEM_PRI` (igual ao ano do arquivo). É o critério dos boletins do Ministério e o recorte do DataSUS, e combina com a série semanal do app, que já usa `semana_sin_pri`.
- **Hanseníase:** usar o ano de `DT_DIAG`, como o Ministério.
- Os demais agravos continuam por `NU_ANO`, até decisão por agravo.

Onde a escolha mais pesa é no ano preliminar mais recente (dengue 2026: −1,5%; hanseníase 2026: −4,9%).

---

## Fontes externas

Todas vêm de resultados de busca. As páginas não foram abertas porque `gov.br` e `repositorio.ufpa.br` estão bloqueados aqui. Conferir antes de citar.

- **Raiva 2022 = 5 casos; 2023 = 2 até setembro:** [Correio Braziliense, set/2023](https://www.correiobraziliense.com.br/brasil/2023/09/5123383-brasil-registrou-cinco-casos-de-raiva-humana-em-2022-e-dois-neste-ano.html) e [Correio Braziliense, set/2023 (2)](https://www.correiobraziliense.com.br/brasil/2023/09/5123479-raiva-humana-preocupa-e-em-dois-anos-sao-sete-casos.html).
- **Raiva: "40 casos entre 2010 e 2021" e "47 entre 2010 e 2023":** apareceram nos trechos de busca, mas não consegui atribuir cada número a um link. Candidatos: [bjihs 5457](https://bjihs.emnuvens.com.br/bjihs/article/download/5457/5409/11980), [unesc](https://unesc.br/sisunesc/uploads/submissoes/3296/405.pdf), [even3](https://static.even3.com/anais/1352614.pdf).
- **Tabela oficial de raiva humana 2010-2025:** [gov.br, tabela-1.pdf](https://www.gov.br/saude/pt-br/assuntos/saude-de-a-a-z/r/raiva/arquivos/tabela-1.pdf). Não abri; recomendo conferir a série toda.
- **Encerramento automático:** [Nota Técnica Conjunta 34/2026](https://www.gov.br/saude/pt-br/composicao/svsa/pni/notas-tecnicas/2026/nota-tecnica-conjunta-no-34-2026-cgvdi-dpni-svsa-ms), sobre imunopreveníveis; cita casos "encerrados automaticamente pelo sistema" e classificação final "vazia ou inconclusiva".
- **Chik 2015 = 38.332 prováveis (18,7/100 mil):** [CONASS, boletim do Ministério SE 13/2016](https://www.conass.org.br/wp-content/uploads/2016/04/2016-014-Dengue-SE13-prelo.pdf) e [Revista Pesquisa FAPESP](https://revistapesquisa.fapesp.br/a-vez-da-chikungunya/).
- **Chik 2016 = 271.824 e 2017 = 185.593 (depois 277.882 e 185.854):** [Bem Paraná (Folhapress)](https://www.bemparana.com.br/noticias/brasil/dengue-zika-e-chikungunya-atingem-cerca-de-2-milhoes-de-pessoas-em-2016/), [temas.sld.cu, ago/2018](https://temas.sld.cu/vigilanciaensalud/2018/08/15/dengue-virus-del-zika-y-chikungunya-en-brasil-11) e [temas.sld.cu, nov/2018](https://temas.sld.cu/vigilanciaensalud/2018/11/19/dengue-virus-del-zika-y-chikungunya-en-brasil-17).
- **Hanseníase:**
  - [Boletim Epidemiológico vol. 56, nº 2 (2025)](https://www.gov.br/saude/pt-br/centrais-de-conteudo/publicacoes/boletins/epidemiologicos/edicoes/2025/boletim-epidemiologico-volume-56-n-2.pdf): 2023 = 22.773;
  - [vol. 57, nº 1 (2026)](https://www.gov.br/saude/pt-br/centrais-de-conteudo/publicacoes/boletins/epidemiologicos/edicoes/2026/boletim-epidemiologico-volume-57-no-1.pdf): 2024 = 22.129;
  - [vol. 57, nº 2 (2026)](https://www.gov.br/saude/pt-br/centrais-de-conteudo/publicacoes/boletins/epidemiologicos/edicoes/2026/boletim-epidemiologico-volume-57-no-2.pdf): 2015-2024 = 238.781.
- **Chagas aguda no Pará (1.515 em 2010-2017; 1.394 em 2015-2019):** trechos de busca. Candidatos: [UFPA, bdm](https://www.bdm.ufpa.br/bitstreams/1481e716-740f-4d28-aa33-6dfaa27579bd/download) e [repositório UFPA](https://repositorio.ufpa.br/handle/2011/11822).
- **LV, "casos novos confirmados" (Caderno de Indicadores do GT Leishmanioses):** citado por estudos secundários na busca, por exemplo [RSD Journal](https://rsdjournal.org/index.php/rsd/article/download/22690/20115/274211) e [Sanare](https://sanare.emnuvens.com.br/sanare/article/download/1500/753). Não verificado no original.
