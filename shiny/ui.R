library(shiny)
library(bslib)
library(shinyWidgets)
library(ggplot2)
library(dplyr)
library(plotly)
library(RMySQL)
library(leaflet)
library(sf)
library(rmapshaper)
library(highcharter)
library(gganimate)#para corrida de barras
library(transformr)#para corrida de barras
library(gifski)#para corrida de barras
library(jsonlite)#para corrida de barras
library(shinyjs)
library(png)

source('sobre_projeto.R')
source("inputs.R")
source('cards.R')
source('server_sql.R')
source('sobre_dtns.R')
source('dtns_brasil.R')
source('tendencia.R')
#source('serie_temporal.R')
#source("app_dengue/serie_temporal.R")


ui <- page_navbar(
  title = 'VigiTrop',
  bg = "#0072B2",
  underline = T,
  nav_panel(title = 'Análises',
            page_sidebar(
              
              sidebar = list(
                useShinyjs(), 
                 
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
                  #selecionar_uf,
                  tipo_mapa,
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
              tags$div(id = "loading", style = "display:none;", class = "modal", 
                       tags$div(class = "modal-content", 
                                tags$h4("Gerando Gráfico..."), 
                                tags$p("Por favor, aguarde."))),
              
              
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
