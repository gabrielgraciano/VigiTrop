cards <- list(
  card(
    full_screen = TRUE,
    card_header("Série Temporal"),
    highchartOutput("monthplot")
  ),
  card(
    full_screen = TRUE,
    card_header('Pirâmide Etária'),
    plotlyOutput('piram_et')
  ),
  card(
    full_screen = TRUE,
    card_header('Gráfico de Barras'),
    highchartOutput('barplot_porcentagem')
  ),
  card(
    full_screen = TRUE,
    card_header('Mapas'),
    leafletOutput('mapa_incid')
  ),
  card(
    full_screen = TRUE,
    card_header('Animação de Barras'),
    imageOutput('bar_chart_race')
  )
)
