# Inputs. As opções vêm dos dados (dados.R): doenças, UFs e anos não ficam
# mais fixos no código. Rótulos curtos: o painel já diz o que se escolhe.

seletor_doenca <- function(id, escolhas = escolhas_doenca) {
  pickerInput(id, "Doença", choices = escolhas, multiple = FALSE)
}

seletor_ano <- function(id) {
  pickerInput(id, "Ano", choices = rev(anos_disponiveis), selected = ano_padrao)
}

seletor_uf <- function(id, multiplo = FALSE, selecionado = BRASIL) {
  pickerInput(id, if (multiplo) "UFs (uma ou mais)" else "UF", choices = escolhas_uf_brasil, selected = selecionado,
              multiple = multiplo, options = pickerOptions(liveSearch = TRUE, noneSelectedText = "Nenhuma",
                                                           liveSearchPlaceholder = "Buscar UF"))
}

botao <- function(id) actionButton(id, "Atualizar gráfico", class = "btn-primary w-100")

#Série temporal----
selecionar_doenca_serie_temporal <- seletor_doenca("doenca_st")
selecionar_uf_st <- seletor_uf("uf_st", multiplo = TRUE)
selecionar_sexo <- pickerInput("sexo", "Sexo", choices = SEXOS, selected = "Ambos", multiple = TRUE)
selecionar_idade <- pickerInput("faixa_etaria", "Faixa etária",
                                choices = c("Todas" = "Todos", stats::setNames(FAIXAS, FAIXAS)),
                                selected = "Todos", multiple = TRUE)
selecionar_periodicidade_st <- radioButtons("periodicidade_st", "Periodicidade", inline = TRUE,
                                            choices = c("Anual" = "anual", "Mensal" = "mensal"))
botao_st <- botao("update_st")

#Pirâmide etária----
selecionar_doenca_piramide_etaria <- seletor_doenca("doenca_pe")
selecionar_uf_pe <- seletor_uf("uf_pe")
selecionar_ano_pe <- seletor_ano("ano_pe")
botao_pe <- botao("update_pe")

#Sexo e raça/cor----
selecionar_doenca_estatistica_descritiva <- seletor_doenca("doenca_ed")
selecionar_uf_ed <- seletor_uf("uf_ed")
selecionar_dist_ed <- radioButtons("dist_ed", "Distribuir por", choices = c("Sexo" = "sexo", "Raça/cor" = "raca"))
# Só para raça/cor: painéis de linhas (um por grupo) ou colunas empilhadas
selecionar_grafico_raca <- conditionalPanel(
  condition = "input.dist_ed == 'raca'",
  radioButtons("grafico_raca", "Gráfico", choices = c("Linhas" = "linhas", "Barras" = "barras"))
)
botao_ed <- botao("update_ed")

#Série semanal----
selecionar_doenca_sem <- seletor_doenca("doenca_sem", escolhas_doenca_semana)
selecionar_uf_sem <- seletor_uf("uf_sem", multiplo = TRUE)
selecionar_periodo_sem <- sliderInput("periodo_sem", "Período (ano da semana)", min = min(anos_disponiveis),
                                      max = max(anos_disponiveis), value = c(max(anos_disponiveis) - 2, max(anos_disponiveis)),
                                      step = 1, sep = "")
botao_sem <- botao("update_sem")

#Mapas----
# Um mapa só, com o ranking das UFs ao lado; a escolha vale para os dois.
selecionar_doenca_map <- seletor_doenca("doenca_map")
selecionar_ano_map <- seletor_ano("ano_map")
tipo_mapa <- radioButtons("tipo_mapa", "Mostrar", choices = c("Incidência" = "incidencia", "Casos absolutos" = "casos"))
botao_map <- botao("update_map")

#UFs por ano----
# Ids "_br" herdados da antiga animação (bar chart race).
selecionar_doenca_br <- seletor_doenca("doenca_br")
tipo_br <- radioButtons("tipo_br", "Valor", choices = c("Incidência", "Casos" = "Casos Absolutos"))
botao_br <- botao("update_br")
