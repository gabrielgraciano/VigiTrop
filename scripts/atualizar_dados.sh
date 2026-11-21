#!/usr/bin/env bash
# Atualização mensal dos dados do VigiTrop: pipeline completo + reinício do app.
#
# Uso (na VM, pelo cron; ver docs/deploy_vm.md):
#   /home/<usuario>/vigitrop/scripts/atualizar_dados.sh
#
# - O pipeline baixa só o que mudou no DataSUS e refaz silver, gold e tendência.
# - Se o pipeline der certo, o app é reiniciado para ler o gold novo (ele lê os
#   dados uma vez, ao iniciar). Fica fora do ar alguns segundos.
# - Se o pipeline falhar, o app NÃO é reiniciado e continua no ar com os dados
#   anteriores. O erro fica no log em data/logs/atualizacao_*.log.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p data/logs
log="data/logs/atualizacao_$(date +%Y%m%d_%H%M%S).log"
exec >>"$log" 2>&1

# Uma atualização por vez (ex.: cron disparou enquanto alguém rodava à mão)
exec 9>data/.atualizacao.lock
if ! flock -n 9; then
  echo "$(date -Is) já existe uma atualização rodando; saindo."
  exit 0
fi

echo "== $(date -Is) início"
docker compose -p vigitrop run --rm pipeline executar
docker compose -p vigitrop restart app
echo "== $(date -Is) fim: dados atualizados e app reiniciado"
