# Conteúdo de cada aba de "Análises". Sem cabeçalho no card: a aba já diz o
# que é, e o título do gráfico diz o que ele mostra.
cards <- list(
  card(
    full_screen = TRUE,
    highchartOutput("monthplot", height = "480px"),
    card_footer(uiOutput("nota_st"))
  ),
  card(
    full_screen = TRUE,
    highchartOutput("piram_et", height = "560px"),
    card_footer(uiOutput("nota_pe"))
  ),
  card(
    full_screen = TRUE,
    highchartOutput("barras", height = "600px"),
    card_footer(uiOutput("nota_ed"))
  ),
  card(
    full_screen = TRUE,
    layout_columns(
      col_widths = c(7, 5),
      tags$div(class = "vt-mapa", uiOutput("mapa_titulo"), leafletOutput("mapa_incid", height = "560px")),
      highchartOutput("ranking_uf", height = "640px")
    ),
    card_footer(uiOutput("nota_map"))
  ),
  card(
    full_screen = TRUE,
    plotlyOutput("bar_chart_race", height = "680px"),
    card_footer(uiOutput("nota_br"))
  ),
  card(
    full_screen = TRUE,
    highchartOutput("serie_semanal", height = "480px"),
    card_footer(uiOutput("nota_sem"))
  )
)
