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
- **Tendência (08/11/2026):** é recalculada pelo pipeline (joinpoint por BIC) e aparece na aba Tendência. A tabela do TCC fica como referência.

## Outras pendências

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
