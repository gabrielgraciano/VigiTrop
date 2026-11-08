# Carregado pelo Shiny antes de ui.R e server.R.

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(shinyWidgets)
  library(plotly)
  library(leaflet)
  library(highcharter)
})

# Números no padrão brasileiro nos gráficos do highcharter
local({
  lang <- getOption("highcharter.lang")
  lang$decimalPoint <- ","
  lang$thousandsSep <- "."
  options(highcharter.lang = lang)
})

source("dados.R")
source("inputs.R")
source("cards.R")
source("sobre_projeto.R")
source("sobre_dtns.R")
source("dtns_brasil.R")
source("tendencia.R")
