# Bibliotecas, dados e inputs: ver global.R (carregado antes deste arquivo).
# Estilo: tema neutro em global.R (tema_app) e www/vigitrop.css.

ui <- page_navbar(
  title = "VigiTrop",
  theme = tema_app,
  bg = "#FFFFFF",
  underline = TRUE,
  nav_panel(title = "Análises",
            page_sidebar(
              sidebar = sidebar(
                width = 280,
                conditionalPanel(
                  condition = "input.navset == 'Mapas'",
                  selecionar_doenca_map,
                  selecionar_ano_map,
                  ranking_mapa,
                  botao_map
                ),
                conditionalPanel(
                  condition = "input.navset == 'Sexo e raça/cor'",
                  selecionar_doenca_estatistica_descritiva,
                  selecionar_uf_ed,
                  selecionar_dist_ed,
                  botao_ed
                ),
                conditionalPanel(
                  condition = "input.navset == 'Série temporal'",
                  selecionar_doenca_serie_temporal,
                  selecionar_uf_st,
                  selecionar_sexo,
                  selecionar_idade,
                  selecionar_periodicidade_st,
                  botao_st
                ),
                conditionalPanel(
                  condition = "input.navset == 'Série semanal'",
                  selecionar_doenca_sem,
                  selecionar_uf_sem,
                  selecionar_periodo_sem,
                  botao_sem
                ),
                conditionalPanel(
                  condition = "input.navset == 'Pirâmide Etária'",
                  selecionar_doenca_piramide_etaria,
                  selecionar_uf_pe,
                  selecionar_ano_pe,
                  botao_pe
                ),
                conditionalPanel(
                  condition = "input.navset == 'Animação - barras'",
                  selecionar_doenca_br,
                  tipo_br,
                  botao_br
                )
              ),
              navset_card_underline(
                id = "navset",
                nav_panel("Mapas", cards[[4]]),
                nav_panel("Sexo e raça/cor", cards[[3]]),
                nav_panel("Série temporal", cards[[1]]),
                nav_panel("Série semanal", cards[[6]]),
                nav_panel("Pirâmide Etária", cards[[2]]),
                nav_panel("Animação - barras", cards[[5]])
              )
            )),
  nav_panel(title = "Tendência", div(tendencia)),
  nav_panel(title = "Sobre o Projeto", div(sobre_projeto_texto)),
  nav_panel(title = "DTNs", div(sobre_dtns_texto)),
  nav_panel(title = "DTNs no Brasil", div(dtns_brasil)),
  nav_spacer(),
  nav_menu(title = "Links",
           align = "right",
           nav_item(tags$a(
             href = "https://github.com/gabrielgraciano/VigiTrop/tree/main",
             target = "_blank",
             tags$span(icon("github"), " GitHub")
           )),
           nav_item(tags$a(
             href = "https://docs.google.com/document/d/1itiFIu9HJICnXQ1I_BfNNt_yYbgqIUq59f2gQVqjrMU/edit?usp=sharing",
             target = "_blank",
             tags$span(icon("file-text"), " TCC")
           ))),
  header = tags$head(
    tags$link(rel = "shortcut icon", href = "favicon.ico"),
    tags$link(rel = "stylesheet", href = "vigitrop.css"),
    tags$script(src = "vigitrop.js"),
    dep_picker
  )
)
