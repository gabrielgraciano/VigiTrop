cards <- list(
  card(
    full_screen = TRUE,
    card_header("Série Temporal"),
    highchartOutput("monthplot"),
    card_footer(uiOutput("nota_st"))
  ),
  card(
    full_screen = TRUE,
    card_header('Pirâmide Etária'),
    plotlyOutput('piram_et'),
    card_footer(uiOutput("nota_pe"))
  ),
  card(
    full_screen = TRUE,
    card_header('Gráfico de Barras'),
    highchartOutput('barplot_porcentagem'),
    card_footer(uiOutput("nota_ed"))
  ),
  card(
    full_screen = TRUE,
    card_header('Mapas'),
    leafletOutput('mapa_incid'),
    card_footer(uiOutput("nota_map"))
  ),
  card(
    full_screen = TRUE,
    card_header('Animação de Barras'),
    plotlyOutput('bar_chart_race', height = "650px"),
    card_footer(uiOutput("nota_br"))
  ),
  card(
    full_screen = TRUE,
    card_header("Série semanal"),
    highchartOutput("serie_semanal"),
    card_footer(uiOutput("nota_sem"))
  )
)
