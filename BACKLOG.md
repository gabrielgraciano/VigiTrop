# Backlog

Questões em aberto do VigiTrop. As definições de caso ficam em `pipeline/config/doencas.yaml`.

A pesquisa completa sobre as definições (08/11/2026) está em [`docs/investigacao_definicoes.md`](docs/investigacao_definicoes.md).

## Para decidir: definições de caso (com recomendação da pesquisa)

### Inconclusivos (`CLASSI_FIN = 8`) em raiva, Chagas e leishmaniose visceral

**Hoje:** o padrão inclui os inconclusivos, como no TCC (decisão de 08/11/2026, pendente desta investigação). A contagem só de confirmados também está no gold.

**O que a investigação achou:**
- **O que é o código 8.** Não aparece em nenhum dicionário. Nos dados, marca o caso que ninguém encerrou no prazo:
  - 95% a 99% estão sem critério de confirmação;
  - 98% a 99,7% foram encerrados 61 dias ou mais depois da notificação (conferido de novo).
- **Raiva:** nenhum dos 575 inconclusivos (2007-2021) tem data de óbito, numa doença com letalidade perto de 100%. Só 6 têm sinal clínico clássico, e nenhum tem exame positivo. O perfil é de exposição a animal, não de doença.
  - Os confirmados batem com o Ministério: 11 em 2018 e 40 de 2010 a 2021.
  - O código 8 some do arquivo a partir de 2022. Com a regra atual, a série cai de 52 (2021) para 2 (2022) por puro artefato, e a tendência do app mostra −64% ao ano de 2020 a 2024 por causa disso.
- **Chagas aguda:** os arquivos de 2007-2011 só trazem confirmados. Com 1+8, a série salta de 190 para 723 em 2012; só com confirmados, fica 190 → 189.
  - Os inconclusivos se espalham por RN, MG e BA, um perfil de Chagas crônica. 82% dos confirmados são do Pará.
- **Leishmaniose visceral:** o peso do código 8 subiu de 6-10% para 16-22% desde 2023, o que suaviza a queda recente.
- **Dengue e chik:** aqui o 8 entra corretamente nos prováveis, como o Ministério faz. Nada muda.

**Recomendação:** o padrão passa a ser só confirmados (`CLASSI_FIN = 1`) nas três doenças, e 1+8 fica como contagem alternativa, ou só para comparação com o TCC. Decidir com a orientadora.

### Serpentes: `ANI_SERPEN = 5` (não peçonhenta) e `9` (ignorado)

- O código 5 é mordida sem envenenamento: só 5,7% recebem soro e 91% são leves. O peso dele triplicou (3,8% → 10,6%) e infla a tendência.
- O código 9 tem 41% com soro e 223 óbitos: são envenenamentos de fato.

**Recomendação:** padrão = `TP_ACIDENT = '1' AND ANI_SERPEN <> '5'`, mantendo o 9.

### Transferências nas leishmanioses (`ENTRADA` / `CLA_TIPO_N = 3`)

- Pesam de 0,7% a 2,7% na LV e 0,5% na LTA. Na LV não há sinal de contagem dupla; na LTA, umas 100 duplicatas prováveis em 19 anos.
- Achado à parte: a LTA conta hoje de 170 a 370 registros por ano encerrados como "mudança de diagnóstico", que não são LTA.

**Recomendação:** excluir as transferências e, na LTA, os encerrados por mudança de diagnóstico.

### Ano de referência (prioridade baixa)

- Os arquivos de dengue e chik já vêm recortados pelo ano epidemiológico dos primeiros sintomas; os demais, pelo ano de notificação.
- Trocar o ano de notificação (`NU_ANO`) pelo de sintomas ou diagnóstico muda menos de 1% nos anos fechados.

**Recomendação:** manter `NU_ANO`.

## Decisões tomadas

- **Inconclusivos (08/11/2026):** continuam na contagem padrão de raiva, Chagas e leishmaniose visceral, até a decisão acima.
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
