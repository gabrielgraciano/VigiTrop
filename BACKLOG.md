# Backlog

Questões em aberto do VigiTrop. As definições de caso ficam em `pipeline/config/doencas.yaml`.

## Investigar: inconclusivos (`CLASSI_FIN = 8`) na contagem de casos

**Situação atual (decisão de 08/11/2026):** os inconclusivos continuam na contagem, como no TCC. Isso vale para raiva humana, doença de Chagas aguda e leishmaniose visceral, que usam por padrão a definição `confirmado_ou_inconclusivo` (`CLASSI_FIN IN ('1','8')`). A contagem só de confirmados também é calculada.

**Por que investigar:** o efeito varia muito entre as doenças.

| Doença | Ano | Só confirmados | Confirmados + inconclusivos |
|---|---|---|---|
| Raiva humana | 2018 | 11 | 66 (6×) |
| Doença de Chagas aguda | 2018 | 380 | 826 (2,2×) |
| Leishmaniose visceral | 2018 | 3.851 | 4.170 (+8%) |

Na raiva, o Ministério da Saúde divulga 11 casos em 2018, o mesmo número dos confirmados.

**O que levantar:**
- O que o código 8 significa em cada agravo. Ele não aparece no dicionário de RAIV nem no de CHAG, mas existe nos dados.
- Como o Ministério e a literatura contam essas doenças (confirmados ou não).
- Se o app deve mostrar as duas contagens, e qual delas como padrão.
- Decidir com a orientadora.

## Decisões tomadas

- **Inconclusivos (08/11/2026):** ficam na contagem padrão de raiva, Chagas e leishmaniose visceral. A investigação continua aberta (seção acima).
- **Hanseníase (08/11/2026):** o padrão é casos novos (`MODOENTR = 1`, sem erro diagnóstico), o indicador oficial. O TCC contava todas as notificações, cerca de 30% a mais. A contagem antiga continua no gold como `legado_tcc`.

- **Dengue e chikungunya (08/11/2026):** o padrão é casos prováveis (notificações menos descartadas, inconclusivos incluídos), como o Ministério e o TCC. Os confirmados continuam no gold.

## Outras pendências já levantadas

- **Chikungunya 2015.** Usa outra codificação de `CLASSI_FIN` (1, 2 e 8, quase sem 13), então "confirmado" sai quase zerado nesse ano. Conferir no dicionário da época.
- **Serpente.** Decidir se entram as não peçonhentas (`ANI_SERPEN = 5`) e as de tipo ignorado (`9`).
- **Leishmanioses.** Decidir se transferências (`ENTRADA` / `CLA_TIPO_N = 3`) saem da contagem.
- **Ano de referência.** Ano da notificação (`NU_ANO`, como no TCC), dos primeiros sintomas (`DT_SIN_PRI`) ou do diagnóstico (`DT_DIAG`, usado pelo Ministério na hanseníase).
- **Validação contra o dump.** Comparar com as tabelas `notifications_*` do MySQL antigo.
- **Bugs no catálogo do PySUS**, contornados no pipeline. Reportar ao projeto (AlertaDengue/PySUS):
  - `ESQUBR10` está sem grupo (`group_id` nulo);
  - `DENGBR21` foi trocado no S3 em 28/09/2026, mas o catálogo ainda anuncia o tamanho e o sha256 da versão anterior.
