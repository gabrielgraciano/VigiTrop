# Deploy na VM da UNIFESP

Como trocar o VigiTrop antigo (`shiny-app` + `mysql-test`) pelo novo (container `app` lendo `data/gold`), com teste antes e volta atrás garantida.

- **VM:** `gabrielgracianodias@172.22.29.19`, acessível só pela VPN da UNIFESP.
- **Site:** `vigitrop.unifesp.br`, que o proxy da UNIFESP manda para a porta **2102** da VM.

## Regras (a VM é compartilhada com o projeto Garu)

- Nunca rodar `docker system prune`, nem `docker compose down` fora do projeto `vigitrop`.
- Sempre usar `-p vigitrop` nos comandos de compose. O `docker-compose.yml` já fixa `name: vigitrop`, então é uma garantia dupla.
- Não mexer em `garu_vm` nem em `hardcore-colden`.
- Os containers antigos só são **parados** (`docker stop`), nunca removidos, até o novo estar estável por alguns dias.

Se o seu usuário não estiver no grupo `docker`, use `sudo` na frente dos comandos `docker`.

## 0. Diagnóstico (só leitura)

Com a VPN ligada, entre na VM (`ssh gabrielgracianodias@172.22.29.19`) e rode:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker compose version
df -h ~ /var/lib/docker
for u in https://nbg1.your-objectstorage.com/pysus/public/catalog.duckdb https://ftp.ibge.gov.br/ https://p3m.dev/ https://pypi.org/simple/ https://registry-1.docker.io/v2/ https://github.com/ http://extensions.duckdb.org/; do printf "%s -> " "$u"; curl -sS -o /dev/null -I -w "%{http_code}\n" --max-time 15 "$u" 2>&1 | tail -1; done
```

O resultado decide o caminho:

- **Caminho A**, se a VM alcança todos os sites (qualquer código HTTP, inclusive 401, 403 ou 404): tudo é construído e atualizado na própria VM, e a atualização mensal roda pelo cron.
- **Caminho B**, se aparecer `000` ou erro: as imagens são construídas no PC e copiadas para a VM. A atualização mensal precisa de outro arranjo, a combinar.
- **`docker compose`:** precisa da versão 2 ou mais nova. Se não existir, é preciso instalar o plugin.

## 1. Código na VM

```bash
cd ~
git clone https://github.com/gabrielgraciano/VigiTrop.git vigitrop
cd vigitrop
git checkout claude/trusting-pasteur-bsuang   # ou main, depois do merge
```

## 2. Dados (gold)

Na primeira vez, o mais rápido é copiar o gold que já foi gerado no PC. São cerca de 4 MB. No **PowerShell do PC**:

```powershell
ssh gabrielgracianodias@172.22.29.19 "mkdir -p ~/vigitrop/data"
scp -r C:\Users\gabir\tcc-vigitrop\vigitrop\data\gold gabrielgracianodias@172.22.29.19:~/vigitrop/data/
```

No caminho A, dá também para gerar tudo na VM (cerca de 0,8 GB de download):

```bash
docker compose -p vigitrop build pipeline
docker compose -p vigitrop run --rm pipeline executar
```

## 3. Imagem do app

**Caminho A** (na VM):

```bash
docker compose -p vigitrop build app
```

**Caminho B** (no PowerShell do PC, com o Docker Desktop):

```powershell
cd C:\Users\gabir\tcc-vigitrop\vigitrop
docker compose build app
docker save -o vigitrop-app.tar vigitrop-app
scp vigitrop-app.tar gabrielgracianodias@172.22.29.19:~/
```

Depois, na VM, `docker load -i ~/vigitrop-app.tar`. São cerca de 3 GB, então a cópia pela VPN pode demorar.

## 4. Teste na porta 2103, sem tocar no site atual

Na VM:

```bash
cd ~/vigitrop
VIGITROP_PORTA=127.0.0.1:2103 docker compose -p vigitrop up -d app
docker compose -p vigitrop logs --tail 20 app
```

`127.0.0.1` faz a porta 2103 ficar acessível só de dentro da VM. Para abrir no seu navegador, crie um túnel. No **PowerShell do PC**, deixe esta janela aberta:

```powershell
ssh -L 2103:localhost:2103 gabrielgracianodias@172.22.29.19
```

Abra `http://localhost:2103` e passe pelas abas.

## 5. A troca

Quando o teste estiver bom, na VM:

```bash
docker stop shiny-app mysql-test                 # PARA os antigos (não remove)
cd ~/vigitrop
echo "VIGITROP_PORTA=2102" > .env                # porta fixa para todos os comandos seguintes
docker compose -p vigitrop up -d app             # recria o app na 2102
docker compose -p vigitrop ps
```

Confira `vigitrop.unifesp.br` (`/` e `/app_ec/`).

- O app novo tem `restart: unless-stopped`, então volta sozinho depois de um reboot da VM. Os antigos não voltavam.
- Com o `mysql-test` parado, a porta 3306, que estava publicada no host, deixa de existir.

### Volta atrás (rollback)

```bash
cd ~/vigitrop && docker compose -p vigitrop stop app
docker start mysql-test shiny-app
```

## 6. Atualização mensal (caminho A)

O script `scripts/atualizar_dados.sh`:
1. roda o pipeline completo;
2. se der certo, reinicia o app;
3. se falhar, deixa o app no ar com os dados anteriores;
4. grava o log em `data/logs/atualizacao_*.log`.

Ele também não roda duas vezes ao mesmo tempo.

Primeiro, teste uma vez à mão:

```bash
~/vigitrop/scripts/atualizar_dados.sh && tail -n 5 ~/vigitrop/data/logs/atualizacao_*.log
```

Depois, agende para todo dia 5, às 3h17:

```bash
crontab -e
# acrescente a linha:
17 3 5 * * /home/gabrielgracianodias/vigitrop/scripts/atualizar_dados.sh
```

Se o docker exigir `sudo`, agende no cron do root (`sudo crontab -e`) com a mesma linha.

## 7. Limpeza (só depois de alguns dias estável)

```bash
docker rm shiny-app mysql-test
docker image ls | grep -E "shiny-app-backup|mysql-test-backup"   # confira antes
docker rmi shiny-app-backup mysql-test-backup
```

Faça um backup do volume do MySQL antes, se quiser guardar o banco antigo. O dump de 31/08/2026 já está no PC.
