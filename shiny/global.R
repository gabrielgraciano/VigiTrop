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

# ---- estilo -------------------------------------------------------------------
# Estilo neutro do design system "Gabriel — Data Decks" (skill present-with-data),
# o indicado para material acadêmico e de saúde. Os mesmos valores estão em
# www/vigitrop.css. Todas as cores usadas em texto dão pelo menos 4,5:1 no branco;
# o cinza de contexto (2,6:1) é só para linhas, pontos e áreas.
CORES <- list(
  tinta = "#1E2024",        # texto, rótulos de valor, linha de base
  tinta_suave = "#555555",  # subtítulos, eixos, fonte
  destaque = "#2563EB",     # série em destaque, sem valência
  secundaria = "#B45309",   # segunda série
  positivo = "#2563EB",     # com valência: o lado bom (incidência caindo)
  negativo = "#DC2626",     # com valência: o lado ruim (incidência subindo)
  contexto = "#94A3B8",     # tudo o que não é a história
  grade = "#E1E1E1"
)
# Séries escolhidas pelo usuário (UFs, sexos): destaque, secundária, tinta e,
# só se forem muitas, outras cores escuras. O nome vai escrito no fim da linha,
# então a cor nunca é a única pista.
PALETA <- c("#2563EB", "#B45309", "#1E2024", "#0E7C7B", "#7B3294", "#64748B", "#BE185D", "#4D7C0F")
COR_SEXO <- c(M = "#2563EB", F = "#B45309")
# Regiões: Norte e Nordeste em laranjas, Sudeste e Sul em azuis, Centro-Oeste em
# cinza, com luminosidades diferentes. Testado nos três tipos de daltonismo
# (menor ΔE entre duas regiões: 23); cada barra também leva a sigla da UF.
COR_REGIAO <- c("Norte" = "#F59E0B", "Nordeste" = "#B45309", "Sudeste" = "#2563EB", "Sul" = "#93C5FD", "Centro-Oeste" = "#A3A3A3")
# Rampa sequencial do mapa e do ranking (Blues, sem os dois tons mais claros,
# que somem no branco); "sem casos" fica num cinza à parte.
RAMPA_MAPA <- c("#C6DBEF", "#9ECAE1", "#6BAED6", "#3182BD", "#08519C")
COR_SEM_CASOS <- "#F1F5F9"
FONTE <- '"IBM Plex Sans", Arial, sans-serif'

tema_app <- bs_theme(
  version = 5,
  bg = "#FFFFFF", fg = CORES$tinta, primary = CORES$destaque, secondary = CORES$tinta_suave,
  base_font = font_collection("IBM Plex Sans", "Arial", "sans-serif"),
  "border-radius" = "0.25rem", "font-size-base" = "0.95rem"
)

estilo_eixo <- list(color = CORES$tinta_suave, fontSize = "13px")
options(
  highcharter.google_fonts = FALSE,  # a fonte vem de www/fonts, não do Google
  highcharter.theme = hc_theme(
    colors = PALETA,
    chart = list(backgroundColor = "#FFFFFF", spacing = list(16, 16, 12, 8),
                 style = list(fontFamily = FONTE, color = CORES$tinta)),
    title = list(align = "left", style = list(color = CORES$tinta, fontSize = "18px", fontWeight = "600")),
    subtitle = list(align = "left", style = list(color = CORES$tinta_suave, fontSize = "14px")),
    xAxis = list(lineColor = CORES$tinta, tickColor = CORES$tinta, tickLength = 4, gridLineWidth = 0,
                 labels = list(style = estilo_eixo),
                 title = list(style = c(estilo_eixo, fontWeight = "normal"))),
    yAxis = list(gridLineColor = CORES$grade, gridLineWidth = 1, lineWidth = 0, tickWidth = 0,
                 labels = list(style = estilo_eixo),
                 title = list(style = c(estilo_eixo, fontWeight = "normal"))),
    legend = list(align = "left", verticalAlign = "top",
                  itemStyle = list(color = CORES$tinta, fontWeight = "normal", fontSize = "13px")),
    tooltip = list(backgroundColor = "#FFFFFF", borderColor = CORES$grade, borderRadius = 0, shadow = FALSE,
                   style = list(color = CORES$tinta, fontSize = "13px")),
    plotOptions = list(
      # No Highcharts, plotOptions.series do tema passa por cima de
      # plotOptions.scatter; por isso a espessura e os marcadores ficam em `line`.
      series = list(animation = list(duration = 300),
                    states = list(hover = list(lineWidthPlus = 0), inactive = list(opacity = 0.35)),
                    dataLabels = list(style = list(color = CORES$tinta, fontSize = "13px", fontWeight = "normal",
                                                   textOutline = "none"))),
      line = list(lineWidth = 2.5, marker = list(enabled = FALSE, symbol = "circle")),
      column = list(borderWidth = 0), bar = list(borderWidth = 0)
    ),
    credits = list(enabled = FALSE),
    navigation = list(buttonOptions = list(symbolStroke = CORES$tinta_suave, theme = list(fill = "transparent")))
  )
)

# Números, meses e menu de exportação em português nos gráficos do highcharter
local({
  lang <- getOption("highcharter.lang")
  lang$decimalPoint <- ","
  lang$thousandsSep <- "."
  lang$months <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto",
                   "setembro", "outubro", "novembro", "dezembro")
  lang$shortMonths <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
  lang$weekdays <- c("domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado")
  lang$numericSymbols <- c(" mil", " mi", " bi", " tri", "", "")
  lang$contextButtonTitle <- "Baixar ou imprimir"
  lang$downloadPNG <- "Baixar PNG"
  lang$downloadJPEG <- "Baixar JPEG"
  lang$downloadPDF <- "Baixar PDF"
  lang$downloadSVG <- "Baixar SVG"
  lang$downloadCSV <- "Baixar CSV"
  lang$downloadXLS <- "Baixar XLS"
  lang$printChart <- "Imprimir"
  lang$viewFullscreen <- "Tela cheia"
  lang$exitFullscreen <- "Sair da tela cheia"
  lang$viewData <- "Ver tabela"
  lang$hideData <- "Esconder tabela"
  lang$resetZoom <- "Desfazer zoom"
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
source("graficos.R")
source("inputs.R")
source("cards.R")
source("sobre_projeto.R")
source("sobre_dtns.R")
source("dtns_brasil.R")
source("tendencia.R")
