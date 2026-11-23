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
    uiOutput("barras"),
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
    highchartOutput("calor_uf", height = "700px"),
    card_footer(uiOutput("nota_br"))
  ),
  card(
    full_screen = TRUE,
    highchartOutput("serie_semanal", height = "480px"),
    card_footer(uiOutput("nota_sem"))
  ),
  card(
    full_screen = TRUE,
    layout_columns(
      col_widths = c(7, 5),
      # O mapa encolhe para caber debaixo do título (que costuma ter duas
      # linhas); sem isso, a legenda era cortada embaixo.
      htmltools::bindFillRole(tags$div(class = "vt-mapa", uiOutput("mun_titulo"), leafletOutput("mapa_mun", height = "560px")),
                              container = TRUE, item = TRUE),
      highchartOutput("ranking_mun", height = "640px")
    ),
    card_footer(uiOutput("nota_mun"))
  )
)
