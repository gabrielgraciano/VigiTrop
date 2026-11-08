# Backlog

Questões em aberto do VigiTrop. As definições de caso ficam em `pipeline/config/doencas.yaml`.

A pesquisa completa sobre as definições (08/11/2026) está em [`docs/investigacao_definicoes.md`](docs/investigacao_definicoes.md).

## Para decidir: definições de caso (com recomendação da pesquisa)

### Transferências nas leishmanioses (`ENTRADA` / `CLA_TIPO_N = 3`), aguardando ok do Gabriel

- Pesam de 0,7% a 2,7% na LV e 0,5% na LTA. Na LV não há sinal de contagem dupla; na LTA, umas 100 duplicatas prováveis em 19 anos.
- Achado à parte: a LTA conta hoje de 170 a 370 registros por ano encerrados como "mudança de diagnóstico", que não são LTA.

**Recomendação:** excluir as transferências e, na LTA, os encerrados por mudança de diagnóstico (`EVOLUCAO = 6`). Manter as recidivas por enquanto, até confirmar o indicador exato do Ministério (LV: 80 a 260 por ano; LTA: 750 a 1.300).

### Ano de referência (prioridade baixa)

- Os arquivos de dengue e chik já vêm recortados pelo ano epidemiológico dos primeiros sintomas; os demais, pelo ano de notificação.
- Trocar o ano de notificação (`NU_ANO`) pelo de sintomas ou diagnóstico muda menos de 1% nos anos fechados.

**Recomendação:** manter `NU_ANO`.

## Decisões tomadas

- **Inconclusivos (08/11/2026, revisto):** o padrão de raiva, Chagas e leishmaniose visceral passa a ser só confirmados (`CLASSI_FIN = 1`), como conta o Ministério. A pesquisa mostrou que o código 8 é encerramento automático por prazo, não diagnóstico (detalhes em `docs/investigacao_definicoes.md`, seção 1). Confirmados + inconclusivos continua no gold como `legado_tcc` (a regra do TCC). Raiva 2018: 11, igual ao Ministério. A queda artificial da tendência da raiva depois de 2021 sumiu.
- **Serpentes (08/11/2026):** sem picada de serpente não peçonhenta (`ANI_SERPEN = 5`), que não causa envenenamento; a DTN da OMS é *snakebite envenoming*. O tipo ignorado (9) fica: 41% receberam soro e houve 223 óbitos.
- **Hanseníase (08/11/2026):** o padrão é casos novos (`MODOENTR = 1`, sem erro diagnóstico), o indicador oficial. O TCC contava todas as notificações, cerca de 30% a mais. A contagem antiga continua no gold como `legado_tcc`.
- **Dengue e chikungunya (08/11/2026):** o padrão é casos prováveis (notificações menos as descartadas, inconclusivos incluídos), como o Ministério e o TCC. Os confirmados continuam no gold.
- **Chikungunya 2014-2016 (08/11/2026, correção):** até meados de 2016 a ficha usava 1 = confirmado e 2 = descartado. A regra antiga só confirmava 665 casos em 2015 e contava os descartados como prováveis. Corrigido: o provável de 2015 dá 18,69 por 100 mil, e o Ministério publica 18,7. O valor do TCC para 2015 (16,03) não sai de nenhuma combinação de códigos.
- **Tendência (08/11/2026):** é recalculada pelo pipeline (joinpoint por BIC) e aparece na aba Tendência. A tabela do TCC fica como referência.

## Outras pendências

- **Mesclar a versão de produção do app.** O app novo partiu do código do repo. A versão em produção (`export/app_from_container/`, no PC do Gabriel) tem textos e mensagens um pouco diferentes, além do `serie_temporal.R`. Fazer um merge de três vias: base = commit `ffc6a09`, a produção (sem o `server_sql.R`, que tem a senha) e o app novo.
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
