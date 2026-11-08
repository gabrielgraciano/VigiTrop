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
RUN printf '%s\n' \
      'run_as shiny;' \
      'server {' \
      '  listen 3838 0.0.0.0;' \
      '  location /app_ec { app_dir /srv/shiny-server; log_dir /var/log/shiny-server; }' \
      '  location / { app_dir /srv/shiny-server; log_dir /var/log/shiny-server; }' \
      '}' > /etc/shiny-server/shiny-server.conf

RUN rm -rf /srv/shiny-server/* \
 && mkdir -p /srv/shiny-server/app_cache \
 && chown -R shiny:shiny /srv/shiny-server
COPY --chown=shiny:shiny . /srv/shiny-server/

EXPOSE 3838
