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
    grafico <- validar(input$grafico_raca, c("linhas", "barras"))
    list(doenca = doenca, uf = uf, por = por, grafico = grafico, dados = dados_barras(doenca, uf, por))
  }, ignoreNULL = FALSE)

  # Sexo: colunas empilhadas. Raça/cor: painéis de linhas ou colunas empilhadas.
  output$barras <- renderUI({
    r <- barras()
    validate(need(any(r$dados$casos > 0), "Não há casos para esse conjunto de filtros."))
    if (r$por == "raca" && r$grafico == "linhas") paineis_raca(r$dados, r$doenca, r$uf)
    else grafico_barras(r$dados, r$doenca, r$uf, r$por)
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
    por <- validar(input$tipo_mapa, c("incidencia", "casos"))
    list(doenca = doenca, ano = ano, por = por, dados = dados_mapa(doenca, ano))
  }, ignoreNULL = FALSE)

  output$mapa_titulo <- renderUI({
    r <- mapa()
    titulo_mapa(r$doenca, r$ano, r$dados, r$por)
  })
  output$mapa_incid <- renderLeaflet({
    r <- mapa()
    grafico_mapa(r$dados, r$doenca, r$ano, r$por)
  })
  output$ranking_uf <- renderHighchart({
    r <- mapa()
    grafico_ranking(r$dados, r$doenca, r$ano, r$por)
  })
  output$nota_map <- renderUI({
    r <- mapa()
    sem <- attr(r$dados, "sem_uf")
    nota_doenca(r$doenca, c(
      "Cores pelos quintis das UFs com casos. Casos absolutos acompanham o tamanho da população; para comparar o risco entre UFs, use a incidência.",
      if (sem > 0) paste(formatar_numero(sem), "caso(s) com UF de residência ignorada não aparecem no mapa nem no ranking.")
    ))
  })

  #UFs por ano----
  # Mapa de calor UF × ano, no lugar da corrida de barras animada (e, antes
  # dela, do GIF de 600 quadros que o app antigo renderizava a cada clique).
  uf_ano <- eventReactive(input$update_br, {
    doenca <- validar(input$doenca_br, escolhas_doenca)
    tipo <- validar(input$tipo_br, c("Casos Absolutos", "Incidência"))
    list(doenca = doenca, tipo = tipo, dados = dados_uf_ano(doenca, tipo))
  }, ignoreNULL = FALSE)

  output$calor_uf <- renderHighchart({
    r <- uf_ano()
    grafico_calor(r$dados, r$doenca, r$tipo)
  })
  output$nota_br <- renderUI(nota_doenca(uf_ano()$doenca,
    "Passe o mouse (ou toque) numa célula para ver o valor. Casos com UF de residência ignorada ficam de fora."))
}
