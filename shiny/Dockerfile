# App Shiny do VigiTrop: lê data/gold (parquet) via DuckDB. Sem MySQL.
# Uso: docker compose up -d --build app   (ver README.md na raiz)
FROM rocker/shiny:4.4.1

# Bibliotecas de sistema dos pacotes binários (sf/units, igraph via highcharter)
RUN apt-get update \
 && apt-get install -y --no-install-recommends libudunits2-0 libgdal30 libgeos-c1v5 libproj22 libglpk40 \
 && rm -rf /var/lib/apt/lists/*

# Pacotes R: binários do snapshot p3m de 2024-10-30 (o mesmo repositório da
# imagem base, então as versões ficam fixas).
RUN install2.r --error --skipinstalled --ncpus 4 \
      duckdb DBI bslib shinyWidgets highcharter plotly leaflet sf jsonlite \
 && Rscript -e 'for (p in c("duckdb","DBI","bslib","shinyWidgets","highcharter","plotly","leaflet","sf","jsonlite")) library(p, character.only = TRUE)'

# shiny-server não repassa variáveis de ambiente do container para o R:
# o caminho do gold vai no Renviron.site. O compose monta ./data/gold aqui.
RUN echo "VIGITROP_GOLD=/srv/dados/gold" >> /usr/local/lib/R/etc/Renviron.site

# Escuta em IPv4 explícito (o padrão [::] falha em redes Docker sem IPv6).
# O app responde em / e também em /app_ec/, caminho do app na VM antiga
# (para o caso de o proxy de vigitrop.unifesp.br apontar para ele).
# preserve_logs: guarda o log de cada processo R (sem isso, o erro some quando o
# processo morre). app_idle_timeout: o processo R fica vivo 30 min sem visitas,
# em vez de 5 s, então o primeiro visitante não espera o carregamento dos dados.
RUN printf '%s\n' \
      'run_as shiny;' \
      'preserve_logs true;' \
      'app_idle_timeout 1800;' \
      'server {' \
      '  listen 3838 0.0.0.0;' \
      '  location /app_ec { app_dir /srv/shiny-server; log_dir /var/log/shiny-server; }' \
      '  location / { app_dir /srv/shiny-server; log_dir /var/log/shiny-server; }' \
      '}' > /etc/shiny-server/shiny-server.conf

RUN rm -rf /srv/shiny-server/* \
 && mkdir -p /srv/shiny-server/app_cache \
 && chown -R shiny:shiny /srv/shiny-server
COPY --chown=shiny:shiny . /srv/shiny-server/

# O proxy da UNIFESP (Tengine) devolve 403 para endereços com "select", como
# shinyWidgets/bootstrap-select-1.14.0-beta2/... (provável regra anti-SQL
# injection). Copiamos os mesmos arquivos do pacote para www/vendor/, com nomes
# neutros; global.R os registra como dependência "bootstrap-select" de versão
# maior, que substitui a original.
RUN set -e; d=$(ls -d /usr/local/lib/R/site-library/shinyWidgets/assets/bootstrap-select-1.14* | tail -n 1) \
 && mkdir -p /srv/shiny-server/www/vendor \
 && cp "$d/js/bootstrap-select.min.js" /srv/shiny-server/www/vendor/bs.min.js \
 && cp "$d/css/bootstrap-select.min.css" /srv/shiny-server/www/vendor/bs.min.css \
 && sed -i '/sourceMappingURL/d' /srv/shiny-server/www/vendor/bs.min.js /srv/shiny-server/www/vendor/bs.min.css \
 && chown -R shiny:shiny /srv/shiny-server/www/vendor

EXPOSE 3838
