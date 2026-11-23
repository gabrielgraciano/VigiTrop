# Backlog

Questões em aberto do VigiTrop. As definições de caso ficam em `pipeline/config/doencas.yaml`.

A pesquisa completa sobre as definições (08/11/2026) está em [`docs/investigacao_definicoes.md`](docs/investigacao_definicoes.md).

## Para decidir: definições de caso (com recomendação da pesquisa)

### Ano de referência (prioridade baixa)

- Os arquivos de dengue e chik já vêm recortados pelo ano epidemiológico dos primeiros sintomas; os demais, pelo ano de notificação.
- Trocar o ano de notificação (`NU_ANO`) pelo de sintomas ou diagnóstico muda menos de 1% nos anos fechados.

**Recomendação:** manter `NU_ANO`.

## Decisões tomadas

- **Inconclusivos (08/11/2026, revisto):** o padrão de raiva, Chagas e leishmaniose visceral passa a ser só confirmados (`CLASSI_FIN = 1`), como conta o Ministério. A pesquisa mostrou que o código 8 é encerramento automático por prazo, não diagnóstico (detalhes em `docs/investigacao_definicoes.md`, seção 1). Confirmados + inconclusivos continua no gold como `legado_tcc` (a regra do TCC). Raiva 2018: 11, igual ao Ministério. A queda artificial da tendência da raiva depois de 2021 sumiu.
- **Serpentes (08/11/2026):** sem picada de serpente não peçonhenta (`ANI_SERPEN = 5`), que não causa envenenamento; a DTN da OMS é *snakebite envenoming*. O tipo ignorado (9) fica: 41% receberam soro e houve 223 óbitos.
- **Leishmanioses (08/11/2026):** sem as transferências (LV: `ENTRADA = 3`; LTA: `CLA_TIPO_N = 3`), que repetem o caso em outra unidade, e, na LTA, sem os encerrados por mudança de diagnóstico (`EVOLUCAO = 6`). Efeito: LV 2018, 3.851 → 3.800; LTA 2018, 17.950 → 17.530. **Pendente:** as recidivas ainda entram (LV: 80 a 260 por ano; LTA: 750 a 1.300). Falta confirmar se o indicador do Ministério as inclui.
- **Hanseníase (08/11/2026):** o padrão é casos novos (`MODOENTR = 1`, sem erro diagnóstico), o indicador oficial. O TCC contava todas as notificações, cerca de 30% a mais. A contagem antiga continua no gold como `legado_tcc`.
- **Dengue e chikungunya (08/11/2026):** o padrão é casos prováveis (notificações menos as descartadas, inconclusivos incluídos), como o Ministério e o TCC. Os confirmados continuam no gold.
- **Chikungunya 2014-2016 (08/11/2026, correção):** até meados de 2016 a ficha usava 1 = confirmado e 2 = descartado. A regra antiga só confirmava 665 casos em 2015 e contava os descartados como prováveis. Corrigido: o provável de 2015 dá 18,69 por 100 mil, e o Ministério publica 18,7. O valor do TCC para 2015 (16,03) não sai de nenhuma combinação de códigos.
- **Versão de produção (08/11/2026):** comparada com o repo (`export/app_from_container`, copiada da VM em 31/08/2026). Os textos das abas e a lógica são iguais. Diferenças: o link "TCC" no menu, que foi incorporado; a aba "Animação - barras" desligada, que continua ligada no app novo porque a animação agora roda no navegador; e o `serie_temporal.R`, um rascunho de depuração não usado e com `browser()`, que não foi trazido.
- **Tendência com autocorrelação (22/11/2026):** como no Joinpoint do TCC, os erros têm autocorrelação de 1ª ordem estimada dos dados. Os joinpoints continuam escolhidos por BIC no ajuste comum; com eles fixos, o modelo é reestimado por Prais-Winsten com ρ por REML (`pipeline/vigitrop_pipeline/tendencia.py`; o porquê, com as simulações, está no docstring). Efeito nos dados de 20/11/2026: nenhum joinpoint mudou; APC e AAPC mudaram no máximo 0,4 ponto; os IC alargaram onde ρ > 0 (serpentes 0,31, esquistossomose 0,24, LV e dengue 0,18). Duas conclusões perderam a significância: a AAPC de picada de serpente (+0,7% → +0,6%/ano) e o trecho 2021–2025 da LV (−6,0% → −5,7%/ano). Pendente: o IC ainda é condicional à posição do joinpoint.
- **Aba "Municípios" (23/11/2026):** mapa dos municípios de uma UF, com o ranking dos 20 maiores ao lado, como na aba "Mapas".
  - Casos pelo município de residência (`ID_MN_RESI`, preenchido em mais de 99,5% das notificações). No DF, tudo em Brasília (o SINAN às vezes traz a região administrativa, `5399xx`).
  - População dos municípios: Contagem 2007, Censos 2010 e 2022 e estimativas pós-2022 do IBGE, interpoladas nos anos entre elas e ajustadas à projeção da UF (detalhes no `pipeline/README.md`). Malha: IBGE 2025, simplificada (`pipeline/scripts/gerar_mapas_municipios.py`).
  - O padrão soma 5 anos (incidência média anual): num ano só, a taxa dos municípios pequenos oscila muito (em 2024, 399 dos 639 municípios com LV tiveram 1 caso). Raiva só com casos absolutos.
  - Pendente: taxa suavizada (Bayes empírico), se a oscilação nos municípios pequenos atrapalhar a leitura.
- **Acessos por celular (21/11/2026):** o app não terá contador de acessos nem serviço de estatística externo. A versão para celular se ajusta sozinha pela largura da tela.
- **Tendência (08/11/2026):** é recalculada pelo pipeline (joinpoint por BIC) e aparece na aba Tendência. A tabela do TCC fica como referência.
- **Visual dos gráficos (21/11/2026):** estilo neutro do design system "Gabriel — Data Decks" (skill present-with-data), em `shiny/graficos.R`, `shiny/www/vigitrop.css` e `vigitrop.js`. A fonte IBM Plex Sans é servida pelo próprio app (`www/fonts`, licença OFL).
  - Um mapa só, com a escolha entre incidência e casos absolutos, como no app online. Ao lado entra o ranking das UFs, que segue a mesma escolha e usa as cores do mapa. As faixas são os quintis das UFs com casos.
  - Sexo em colunas 100% empilhadas, como no app online. Raça/cor com duas opções: painéis de linhas (um por grupo, todos na mesma escala) ou as colunas empilhadas.
  - A corrida de barras animada virou a aba "UFs por ano" (21/11/2026): mapa de calor UF × ano, com todas as UFs e anos na mesma escala. A animação mostrava um ano por vez, com a escala mudando a cada ano.
  - **Celular (21/11/2026):** filtros antes do gráfico (antes ficavam no fim da página); abas numa linha com rolagem lateral; nos gráficos estreitos, legenda no alto no lugar dos nomes no fim das linhas, barras de sexo e raça/cor deitadas, siglas no ranking e menos marcas nos eixos (regras `responsive` do Highcharts, em `compacto()` de `graficos.R`); ao clicar em "Atualizar gráfico", a página rola até o gráfico.
  - As taxas não são mais arredondadas em `dados.R`. Antes, 1 caso de raiva em MG virava 0,00 e sumia do mapa.

## Outras pendências

- **Deploy na VM (20/11/2026).** O app está montado na VM e em teste na porta 2103. O pipeline não roda lá, porque a CPU virtual não tem x86-64-v2 (NumPy ≥ 2.4); ele roda no GitHub Actions e publica o gold como release. Falta: a troca para a porta 2102; o cron diário do `scripts/atualizar_da_release.sh`; e juntar a branch na `main`, para o agendamento mensal do Actions valer. Opcional: pedir à TI para trocar o tipo de CPU da VM.
- **Deploy na VM: caminho da URL.** O app antigo ficava em `/srv/shiny-server/app_ec`. O novo responde em `/` e em `/app_ec/`. Confirmar para onde o proxy de `vigitrop.unifesp.br` aponta.
- **Definição alternativa no app.** O gold já tem todas as contagens (confirmados, prováveis, regra do TCC). O app mostra só a padrão de cada doença; dá para oferecer a troca na interface.
- **Validação contra o dump.** Comparar com as tabelas `notifications_*` do MySQL antigo.
- **Dicionários no repo.**
  - `Dicionarios/dic_raiva.pdf` é o do atendimento antirrábico, não o de raiva humana, que falta no repo.
  - `dic_dengue.pdf` e `dic_chikungunya.pdf` são o mesmo arquivo.
  - Falta o dicionário da ficha de chik do SINAN NET (2014-2016).
  - `dic_animais_peconhentospdf` está sem o ponto antes da extensão.
- **Bugs no catálogo do PySUS**, contornados no pipeline. Reportar ao projeto (AlertaDengue/PySUS):
  - `ESQUBR10` está sem grupo (`group_id` nulo);
  - `DENGBR21` foi trocado no S3 em 28/09/2026, mas o catálogo ainda anuncia o tamanho e o sha256 da versão anterior.
