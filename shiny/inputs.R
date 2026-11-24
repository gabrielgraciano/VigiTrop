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
# Uma aba só para as séries anual, mensal e semanal. UF e sexo viram linhas;
# faixa etária e raça/cor são filtros (somam o que for escolhido).
selecionar_doenca_serie_temporal <- seletor_doenca("doenca_st")
selecionar_uf_st <- seletor_uf("uf_st", multiplo = TRUE)
selecionar_sexo <- pickerInput("sexo", "Sexo", choices = SEXOS, selected = "Ambos", multiple = TRUE)
selecionar_idade <- pickerInput("faixa_etaria", "Faixa etária",
                                choices = c("Todas" = "Todos", stats::setNames(FAIXAS, FAIXAS)),
                                selected = "Todos", multiple = TRUE)
selecionar_raca_st <- pickerInput("raca_st", "Raça/cor", choices = c("Todas" = "Todas", stats::setNames(names(RACAS), RACAS)),
                                  selected = "Todas", multiple = TRUE)
selecionar_periodicidade_st <- radioButtons("periodicidade_st", "Periodicidade", inline = TRUE, choices = PERIODICIDADES)
selecionar_periodo_st <- sliderInput("periodo_st", "Período", min = min(anos_disponiveis), max = max(anos_disponiveis),
                                     value = range(anos_disponiveis), step = 1, sep = "")
# Incidência só sem filtro de raça/cor (a população do IBGE não tem essa abertura)
selecionar_metrica_st <- tagList(
  conditionalPanel(
    condition = "!input.raca_st || input.raca_st.indexOf('Todas') > -1",
    radioButtons("metrica_st", "Mostrar", choices = c("Incidência" = "incidencia", "Casos absolutos" = "casos"))
  ),
  conditionalPanel(
    condition = "input.raca_st && input.raca_st.indexOf('Todas') == -1",
    tags$p(class = "form-text", "Com raça/cor escolhida, o gráfico mostra casos: a população do IBGE não tem raça/cor.")
  )
)
botao_st <- botao("update_st")

#Pirâmide etária----
selecionar_doenca_piramide_etaria <- seletor_doenca("doenca_pe")
selecionar_uf_pe <- seletor_uf("uf_pe")
selecionar_ano_pe <- seletor_ano("ano_pe")
# Incidência = taxa específica por idade e sexo (tira o efeito do tamanho de cada faixa)
tipo_pe <- radioButtons("tipo_pe", "Mostrar", choices = c("Casos absolutos" = "casos", "Incidência" = "incidencia"))
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

#Mapas----
# Um mapa só, com o ranking das UFs ao lado; a escolha vale para os dois.
selecionar_doenca_map <- seletor_doenca("doenca_map")
selecionar_ano_map <- seletor_ano("ano_map")
tipo_mapa <- radioButtons("tipo_mapa", "Mostrar", choices = c("Incidência" = "incidencia", "Casos absolutos" = "casos"))
botao_map <- botao("update_map")

#Municípios----
# Uma UF por vez, com os anos somados (um ano só deixa a taxa instável nos
# municípios pequenos). O padrão são os 5 últimos anos com dados finais.
selecionar_doenca_mun <- seletor_doenca("doenca_mun")
selecionar_uf_mun <- pickerInput("uf_mun", "UF", choices = escolhas_uf, selected = "35",
                                 options = pickerOptions(liveSearch = TRUE, liveSearchPlaceholder = "Buscar UF"))
# Busca de um município da UF (opcional): o mapa dá zoom nele e o ranking o mostra
selecionar_municipio_mun <- pickerInput("municipio_mun", "Município (opcional)", choices = escolhas_municipio("35"),
                                        selected = SEM_MUNICIPIO,
                                        options = pickerOptions(liveSearch = TRUE, liveSearchNormalize = TRUE, size = 10,
                                                                liveSearchPlaceholder = "Buscar município"))
selecionar_periodo_mun <- sliderInput("periodo_mun", "Período", min = min(anos_disponiveis), max = max(anos_disponiveis),
                                      value = c(ano_padrao - 4, ano_padrao), step = 1, sep = "")
tipo_mun <- conditionalPanel(
  condition = paste0("![", paste0("'", DOENCAS_SO_CASOS, "'", collapse = ","), "].includes(input.doenca_mun)"),
  radioButtons("tipo_mun", "Mostrar", choices = c("Incidência" = "incidencia", "Casos absolutos" = "casos"))
)
botao_mun <- botao("update_mun")

#UFs por ano----
# Ids "_br" herdados da antiga animação (bar chart race).
selecionar_doenca_br <- seletor_doenca("doenca_br")
tipo_br <- radioButtons("tipo_br", "Valor", choices = c("Incidência", "Casos" = "Casos Absolutos"))
botao_br <- botao("update_br")
