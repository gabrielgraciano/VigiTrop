# Carregado pelo Shiny antes de ui.R e server.R.

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(shinyWidgets)
  library(plotly)
  library(leaflet)
  library(highcharter)
})

# Sem cache do sass em disco: com / e /app_ec/, o shiny-server sobe processos R
# separados que escreveriam no mesmo app_cache/sass ao mesmo tempo. Compilar o
# CSS a cada processo leva menos de 1 s.
options(sass.cache = FALSE)

# Números no padrão brasileiro nos gráficos do highcharter
local({
  lang <- getOption("highcharter.lang")
  lang$decimalPoint <- ","
  lang$thousandsSep <- "."
  options(highcharter.lang = lang)
})

# bootstrap-select (menus do shinyWidgets) servido de www/vendor/, sem "select"
# no endereço: o proxy da UNIFESP bloqueia (403) o caminho original. Os arquivos
# são copiados no build da imagem (Dockerfile). Sem eles (ex.: rodando no RStudio),
# vale a dependência original do shinyWidgets.
dep_picker <- if (file.exists(file.path("www", "vendor", "bs.min.js"))) {
  htmltools::htmlDependency("bootstrap-select", "99.0.0", src = c(href = "vendor"),
                            script = "bs.min.js", stylesheet = "bs.min.css")
}

source("dados.R")
source("inputs.R")
source("cards.R")
source("sobre_projeto.R")
source("sobre_dtns.R")
source("dtns_brasil.R")
source("tendencia.R")
