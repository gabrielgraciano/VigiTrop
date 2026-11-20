#!/usr/bin/env bash
# Atualiza data/gold a partir da release mais recente do GitHub e reinicia o app.
#
# É o caminho da VM da UNIFESP, onde o pipeline não roda (a CPU virtual não tem
# x86-64-v2). O pipeline roda no GitHub Actions (.github/workflows/atualizar_dados.yml)
# e publica gold.tar.gz numa release.
#
# Uso (cron do root na VM, ver docs/deploy_vm.md):
#   /home/<usuario>/vigitrop/scripts/atualizar_da_release.sh
#
# - Sem release nova: só registra "sem novidade" no log e sai.
# - Com release nova: confere o sha256 e o conteúdo, guarda o gold atual em
#   data/gold.anterior, troca os arquivos e reinicia o app.
# - Qualquer falha antes da troca deixa o app como estava.
# Log: data/logs/atualizacao_release.log
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="${VIGITROP_REPO:-gabrielgraciano/VigiTrop}"
BASE="${VIGITROP_RELEASE_URL:-https://github.com/$REPO/releases/latest/download}"

mkdir -p data/logs
exec >>data/logs/atualizacao_release.log 2>&1

exec 9>data/.atualizacao.lock
if ! flock -n 9; then
  echo "$(date -Is) já existe uma atualização rodando; saindo."
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --retry 3 --max-time 120 -o "$tmp/gold.tar.gz.sha256" "$BASE/gold.tar.gz.sha256"
novo="$(cut -d' ' -f1 "$tmp/gold.tar.gz.sha256")"
atual="$(cat data/gold/.release_sha256 2>/dev/null || true)"
if [[ "$novo" == "$atual" ]]; then
  echo "$(date -Is) sem novidade (release ${novo:0:12})"
  exit 0
fi

rotulo_atual="${atual:0:12}"
echo "== $(date -Is) release nova ${novo:0:12} (atual: ${rotulo_atual:-nenhuma})"
curl -fsSL --retry 3 --max-time 600 -o "$tmp/gold.tar.gz" "$BASE/gold.tar.gz"
(cd "$tmp" && sha256sum -c --quiet gold.tar.gz.sha256)

# Só aceita gold/<arquivo> (nada de caminhos absolutos, "..", subpastas ou links)
if tar -tzf "$tmp/gold.tar.gz" | grep -vqE '^gold/([A-Za-z0-9_.-]+)?$'; then
  echo "conteúdo inesperado no gold.tar.gz; nada foi trocado"
  exit 1
fi
mkdir "$tmp/x"
tar --no-same-owner --no-same-permissions -xzf "$tmp/gold.tar.gz" -C "$tmp/x"
for f in casos.parquet populacao.parquet doencas.parquet arquivos.parquet meta.json; do
  [[ -s "$tmp/x/gold/$f" && ! -L "$tmp/x/gold/$f" ]] || { echo "faltou $f na release; nada foi trocado"; exit 1; }
done

# Troca arquivo a arquivo DENTRO de data/gold: a pasta está montada no container
# (bind mount), então ela mesma não pode ser renomeada.
mkdir -p data/gold
rm -rf data/gold.anterior && cp -a data/gold data/gold.anterior
for f in "$tmp"/x/gold/*; do
  nome="$(basename "$f")"
  install -m 0644 "$f" "data/gold/.$nome.novo"
  mv -f "data/gold/.$nome.novo" "data/gold/$nome"
done
echo "$novo" > data/gold/.release_sha256

docker compose -p vigitrop restart app
echo "== $(date -Is) gold atualizado e app reiniciado"
