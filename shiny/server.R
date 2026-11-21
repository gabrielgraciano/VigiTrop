# Server. Os dados e os cálculos ficam em dados.R e os gráficos em graficos.R;
# aqui só entram os filtros. Cada gráfico é recalculado ao clicar em
# "Atualizar gráfico" (e uma vez na abertura, com os valores padrão).

server <- function(input, output, session) {

  #Tendência----
  tend <- reactive({
    doenca <- validar(input$doenca_tend, escolhas_doenca)
    list(doenca = doenca, t = tendencia_doenca(doenca),
         obs = serie_incidencia(doenca, BRASIL, "Ambos", "Todos"))
  })

  output$tend_plot <- renderHighchart({
    r <- tend()
    validate(need(!is.null(r$t), "Tendência ainda não calculada. Rode o comando `tendencia` do pipeline."))
    grafico_tendencia(r$t, r$obs, r$doenca)
  })
  output$tend_tabela <- renderUI({
    t <- tend()$t
    if (!is.null(t)) tabela_tendencia(t)
  })
  output$nota_tend <- renderUI({
    r <- tend()
    aviso <- if (!is.null(r$t)) stats::na.omit(unique(r$t$aviso)) else character()
    nota_doenca(r$doenca, c(if (length(aviso)) paste(aviso, collapse = " "),
                            "Crescente ou decrescente: o IC 95% não contém o zero; estável: contém."))
  })

  #Série temporal----
  serie <- eventReactive(input$update_st, {
    doenca <- validar(input$doenca_st, escolhas_doenca)
    ufs_sel <- validar(input$uf_st, escolhas_uf_brasil)
    sexos <- validar(input$sexo, SEXOS)
    faixas <- validar(input$faixa_etaria, c("Todos", FAIXAS))
    periodicidade <- validar(input$periodicidade_st, c("anual", "mensal"))
    linhas <- list()
    for (u in ufs_sel) for (s in sexos) {
      d <- serie_incidencia(doenca, u, s, faixas, periodicidade)
      # O nome vai escrito no fim da linha: só a UF, e o sexo quando ele varia
      d$serie <- if (length(sexos) > 1 || s != "Ambos") paste(nome_uf(u), rotulo_sexo(s), sep = " · ") else nome_uf(u)
      linhas[[length(linhas) + 1]] <- d
    }
    detalhe <- if (!"Todos" %in% faixas) paste("Faixas etárias:", paste(faixas, collapse = ", "))
    list(doenca = doenca, periodicidade = periodicidade, dados = do.call(rbind, linhas), detalhe = detalhe)
  }, ignoreNULL = FALSE)

  output$monthplot <- renderHighchart({
    r <- serie()
    grafico_serie(r$dados, r$doenca, r$periodicidade == "mensal", r$detalhe)
  })
  output$nota_st <- renderUI({
    r <- serie()
    nota_doenca(r$doenca, if (r$periodicidade == "mensal") paste(
      "Mensal: casos notificados no mês (data de notificação) por 100 mil habitantes, com a população do ano.",
      "Os 12 meses somam a incidência anual."))
  })

  #Pirâmide etária----
  piramide <- eventReactive(input$update_pe, {
    doenca <- validar(input$doenca_pe, escolhas_doenca)
    uf <- validar(input$uf_pe, escolhas_uf_brasil)
    ano <- as.integer(validar(input$ano_pe, as.character(anos_disponiveis)))
    list(doenca = doenca, uf = uf, ano = ano, dados = dados_piramide(doenca, uf, ano))
  }, ignoreNULL = FALSE)

  output$piram_et <- renderHighchart({
    r <- piramide()
    validate(need(sum(r$dados$casos) > 0, "Não há casos para esse conjunto de filtros."))
    grafico_piramide(r$dados, r$doenca, r$uf, r$ano)
  })
  output$nota_pe <- renderUI({
    r <- piramide()
    sem <- attr(r$dados, "sem_idade")
    nota_doenca(r$doenca, if (sem > 0) paste(formatar_numero(sem), "caso(s) com idade ignorada não aparecem na pirâmide."))
  })

  #Sexo e raça/cor----
  barras <- eventReactive(input$update_ed, {
    doenca <- validar(input$doenca_ed, escolhas_doenca)
    uf <- validar(input$uf_ed, escolhas_uf_brasil)
    por <- validar(input$dist_ed, c("sexo", "raca"))
    list(doenca = doenca, uf = uf, por = por, dados = dados_barras(doenca, uf, por))
  }, ignoreNULL = FALSE)

  output$barras <- renderUI({
    r <- barras()
    validate(need(any(r$dados$casos > 0), "Não há casos para esse conjunto de filtros."))
    if (r$por == "sexo") grafico_sexo(r$dados, r$doenca, r$uf) else paineis_raca(r$dados, r$doenca, r$uf)
  })
  output$nota_ed <- renderUI({
    r <- barras()
    nota_doenca(r$doenca, if (r$por == "sexo") "Casos com sexo ignorado não entram na porcentagem."
                else "Raça/cor ignorada ou em branco entra como \"Ignorada\". Sem incidência por raça/cor: a projeção do IBGE não tem essa abertura.")
  })

  #Série semanal----
  semanal <- eventReactive(input$update_sem, {
    doenca <- validar(input$doenca_sem, escolhas_doenca_semana)
    ufs_sel <- validar(input$uf_sem, escolhas_uf_brasil)
    periodo <- as.integer(validar(input$periodo_sem, anos_disponiveis))
    list(doenca = doenca, dados = dados_semana(doenca, ufs_sel, min(periodo), max(periodo)))
  }, ignoreNULL = FALSE)

  output$serie_semanal <- renderHighchart({
    r <- semanal()
    validate(need(nrow(r$dados) > 0, "Não há semanas nesse período."))
    grafico_semanal(r$dados, r$doenca)
  })
  output$nota_sem <- renderUI(nota_doenca(semanal()$doenca, paste(
    "Semana epidemiológica de início dos sintomas (domingo a sábado), não ano de notificação: os totais",
    "podem diferir um pouco das outras abas. As semanas mais recentes ficam incompletas até as notificações",
    "serem digitadas. Hanseníase e leishmaniose tegumentar não têm esse campo.")))

  #Mapas----
  mapa <- eventReactive(input$update_map, {
    doenca <- validar(input$doenca_map, escolhas_doenca)
    ano <- as.integer(validar(input$ano_map, as.character(anos_disponiveis)))
    por <- validar(input$ranking_map, c("incidencia", "casos"))
    list(doenca = doenca, ano = ano, por = por, dados = dados_mapa(doenca, ano))
  }, ignoreNULL = FALSE)

  output$mapa_titulo <- renderUI({
    r <- mapa()
    titulo_mapa(r$doenca, r$ano, r$dados)
  })
  output$mapa_incid <- renderLeaflet({
    r <- mapa()
    grafico_mapa(r$dados, r$doenca, r$ano)
  })
  output$ranking_uf <- renderHighchart({
    r <- mapa()
    grafico_ranking(r$dados, r$doenca, r$ano, r$por)
  })
  output$nota_map <- renderUI({
    r <- mapa()
    sem <- attr(r$dados, "sem_uf")
    nota_doenca(r$doenca, c(
      "Mapa: incidência, para não confundir mais casos com mais população. Faixas pelos quintis das UFs com casos.",
      if (sem > 0) paste(formatar_numero(sem), "caso(s) com UF de residência ignorada não aparecem no mapa nem no ranking.")
    ))
  })

  #Animação de barras----
  # Animação no navegador (plotly), no lugar do GIF de 600 quadros que o app
  # antigo renderizava no servidor a cada clique.
  corrida <- eventReactive(input$update_br, {
    doenca <- validar(input$doenca_br, escolhas_doenca)
    tipo <- validar(input$tipo_br, c("Casos Absolutos", "Incidência"))
    list(doenca = doenca, tipo = tipo, dados = dados_corrida(doenca, tipo))
  }, ignoreNULL = FALSE)

  output$bar_chart_race <- renderPlotly({
    r <- corrida()
    grafico_corrida(r$dados, r$doenca, r$tipo)
  })
  output$nota_br <- renderUI(nota_doenca(corrida()$doenca, legenda_regioes()))
}
