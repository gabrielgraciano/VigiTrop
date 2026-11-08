# Inputs. As opções vêm dos dados (dados.R): doenças, UFs e anos não ficam
# mais fixos no código.

seletor_doenca <- function(id) {
  pickerInput(id, "Selecione a doença de interesse", choices = escolhas_doenca, multiple = FALSE)
}

seletor_ano <- function(id) {
  pickerInput(id, "Selecione o ano", choices = rev(anos_disponiveis), selected = ano_padrao)
}

seletor_uf <- function(id, multiplo = FALSE, selecionado = BRASIL) {
  pickerInput(id, "Selecione a UF:", choices = escolhas_uf_brasil, selected = selecionado, multiple = multiplo,
              options = pickerOptions(liveSearch = TRUE))
}

#Série temporal----
selecionar_doenca_serie_temporal <- seletor_doenca("doenca_st")
selecionar_uf_st <- seletor_uf("uf_st", multiplo = TRUE)
selecionar_sexo <- pickerInput("sexo", "Selecione o sexo:", choices = SEXOS, selected = "Ambos", multiple = TRUE)
selecionar_idade <- pickerInput("faixa_etaria", "Selecione a faixa etária:",
                                choices = c("Todas" = "Todos", stats::setNames(FAIXAS, FAIXAS)),
                                selected = "Todos", multiple = TRUE)
botao_st <- actionButton("update_st", "Atualizar plot")

#Pirâmide etária----
selecionar_doenca_piramide_etaria <- seletor_doenca("doenca_pe")
selecionar_uf_pe <- seletor_uf("uf_pe")
selecionar_ano_pe <- seletor_ano("ano_pe")
botao_pe <- actionButton("update_pe", "Atualizar plot")

#Gráfico de barras----
selecionar_doenca_estatistica_descritiva <- seletor_doenca("doenca_ed")
selecionar_uf_ed <- seletor_uf("uf_ed")
botao_ed <- actionButton("update_ed", "Atualizar plot")

#Mapas----
selecionar_doenca_map <- seletor_doenca("doenca_map")
selecionar_ano_map <- seletor_ano("ano_map")
tipo_mapa <- radioButtons("tipo_mapa", "Selecione o tipo de mapa", choices = c("Casos Absolutos", "Incidência"))
botao_map <- actionButton("update_map", "Atualizar plot")

#Animação de barras----
# Id próprio: antes a animação reaproveitava o `tipo_mapa` do painel de mapas
# (dois inputs com o mesmo id na página).
selecionar_doenca_br <- seletor_doenca("doenca_br")
tipo_br <- radioButtons("tipo_br", "Selecione o tipo de valor", choices = c("Casos Absolutos", "Incidência"))
botao_br <- actionButton("update_br", "Atualizar plot")
