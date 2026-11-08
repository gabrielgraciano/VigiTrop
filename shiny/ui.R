# Bibliotecas, dados e inputs: ver global.R (carregado antes deste arquivo).

ui <- page_navbar(
  title = 'VigiTrop',
  bg = "#0072B2",
  underline = T,
  nav_panel(title = 'Análises',
            page_sidebar(
              
              sidebar = list(
                conditionalPanel(
                  condition = "input.navset == 'Mapas'",
                  selecionar_doenca_map,
                  selecionar_ano_map,
                  tipo_mapa,
                  botao_map
                ),
                
                conditionalPanel(
                  condition = "input.navset == 'Gráfico de Barras'",
                  selecionar_doenca_estatistica_descritiva,
                  selecionar_uf_ed,
                  botao_ed
                  
                ),
                
                conditionalPanel(
                  condition = "input.navset == 'Série temporal'",
                  selecionar_doenca_serie_temporal,
                  selecionar_uf_st,
                  selecionar_sexo,
                  selecionar_idade,
                  botao_st
                  
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
                ),
                
                conditionalPanel(
                  condition = "input.navset == 'Análise de Tendência'"
                )
                
              ),
              navset_card_underline(
                id = "navset",
                nav_panel('Mapas', cards[[4]]),
                nav_panel('Gráfico de Barras', cards[[3]]),
                nav_panel('Série temporal', cards[[1]]),
                nav_panel('Pirâmide Etária', cards[[2]]),
                nav_panel('Animação - barras', cards[[5]]),
                
                
                
                
              ),
            )),
  nav_panel(title = 'Tendência', div(tendencia)),
  nav_panel(title = 'Sobre o Projeto', div(sobre_projeto_texto)),
  nav_panel(title = 'DTNs', div(sobre_dtns_texto)),
  nav_panel(title = 'DTNs no Brasil', div(dtns_brasil)),
  nav_spacer(),
  nav_menu(title = 'Links',
           align = 'right',
           nav_item(tags$a(
             href = "https://github.com/gabrielgraciano/VigiTrop/tree/main",
             target = "_blank",
             tags$span(icon("github"), " GitHub")
           )),
           nav_item('link_tcc')),
  tags$head(
    tags$link(rel = "shortcut icon", href = "favicon.ico")
  ),
  
)
