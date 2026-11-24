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
    grafico_tendencia(r$t, r$obs, r$doenca, log = isTRUE(input$log_tend))
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
  # Anual, mensal ou semanal numa aba só. Cada UF × sexo escolhido vira uma linha;
  # faixa etária e raça/cor filtram (somam o que foi escolhido).
  serie <- eventReactive(input$update_st, {
    validate(need(tem_series_completas, "As séries com raça/cor ainda não chegaram: falta atualizar o gold."))
    doenca <- validar(input$doenca_st, escolhas_doenca)
    ufs_sel <- validar(input$uf_st, escolhas_uf_brasil)
    sexos <- validar(input$sexo, SEXOS)
    faixas <- validar(input$faixa_etaria, c("Todos", FAIXAS))
    racas <- validar(input$raca_st, c("Todas", names(RACAS)))
    periodicidade <- validar(input$periodicidade_st, PERIODICIDADES)
    periodo <- as.integer(validar(input$periodo_st, anos_disponiveis))
    validate(need(periodicidade != "semanal" || doenca %in% doencas_com_semana,
                  "Hanseníase e leishmaniose tegumentar não têm a semana de início dos sintomas. Escolha a série mensal ou anual."))
    # Com raça/cor filtrada só há casos (sem população por raça/cor)
    metrica <- if ("Todas" %in% racas) validar(input$metrica_st, c("incidencia", "casos")) else "casos"
    linhas <- list()
    for (u in ufs_sel) for (s in sexos) {
      d <- dados_serie(doenca, periodicidade, u, s, faixas, racas, min(periodo), max(periodo))
      if (!nrow(d)) next
      # O nome vai escrito no fim da linha: só a UF, e o sexo quando ele varia
      d$serie <- if (length(sexos) > 1 || s != "Ambos") paste(nome_uf(u), rotulo_sexo(s), sep = " · ") else nome_uf(u)
      linhas[[length(linhas) + 1]] <- d
    }
    validate(need(length(linhas) > 0, "Não há dados dessa doença no período escolhido."))
    dados <- do.call(rbind, linhas)
    detalhe <- c(if (!"Todos" %in% faixas) paste("Faixas etárias:", paste(faixas, collapse = ", ")),
                 if (!"Todas" %in% racas) paste("Raça/cor:", paste(RACAS[racas], collapse = ", ")))
    list(doenca = doenca, periodicidade = periodicidade, metrica = metrica, dados = dados, por_raca = !"Todas" %in% racas,
         detalhe = if (length(detalhe)) paste(detalhe, collapse = ". "))
  }, ignoreNULL = FALSE)

  output$monthplot <- renderHighchart({
    r <- serie()
    grafico_serie(r$dados, r$doenca, r$periodicidade, r$metrica, r$detalhe)
  })
  output$nota_st <- renderUI({
    r <- serie()
    nota_doenca(r$doenca, c(
      switch(r$periodicidade,
             anual = "Anual: ano de notificação.",
             mensal = "Mensal: mês da data de notificação; os 12 meses somam o ano.",
             semanal = paste("Semanal: semana epidemiológica de início dos sintomas (domingo a sábado), não a data de notificação;",
                             "os totais podem diferir um pouco das outras séries. As semanas mais recentes ficam incompletas",
                             "até as notificações serem digitadas.")),
      if (r$metrica == "incidencia" && r$periodicidade != "anual") "A incidência usa a população do ano.",
      if (r$por_raca) "Por raça/cor só há casos: a projeção do IBGE não tem população por raça/cor.",
      "Casos com sexo, faixa etária ou raça/cor ignorados só entram quando a opção é \"Ambos\" ou \"Todas\"."
    ))
  })

  #Pirâmide etária----
  piramide <- eventReactive(input$update_pe, {
    doenca <- validar(input$doenca_pe, escolhas_doenca)
    uf <- validar(input$uf_pe, escolhas_uf_brasil)
    ano <- as.integer(validar(input$ano_pe, as.character(anos_disponiveis)))
    por <- validar(input$tipo_pe, c("casos", "incidencia"))
    list(doenca = doenca, uf = uf, ano = ano, por = por, dados = dados_piramide(doenca, uf, ano))
  }, ignoreNULL = FALSE)

  output$piram_et <- renderHighchart({
    r <- piramide()
    validate(need(sum(r$dados$casos) > 0, "Não há casos para esse conjunto de filtros."))
    grafico_piramide(r$dados, r$doenca, r$uf, r$ano, r$por)
  })
  output$nota_pe <- renderUI({
    r <- piramide()
    sem <- attr(r$dados, "sem_idade")
    nota_doenca(r$doenca, c(
      if (r$por == "incidencia") paste(
        "Incidência: casos da faixa etária e do sexo ÷ população da mesma faixa e sexo (projeção do IBGE) × 100 mil.",
        "Em faixas com poucos casos ou pouca gente (90 ou mais, por exemplo), a taxa oscila muito de um ano para outro."),
      if (sem > 0) paste(formatar_numero(sem), "caso(s) com idade ignorada não aparecem na pirâmide.")))
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

  #Municípios----
  # A lista de municípios acompanha a UF escolhida (e volta para "Nenhum")
  observeEvent(input$uf_mun, {
    uf <- validar(input$uf_mun, escolhas_uf)
    updatePickerInput(session, "municipio_mun", choices = escolhas_municipio(uf), selected = SEM_MUNICIPIO)
  }, ignoreInit = TRUE)

  municipal <- eventReactive(input$update_mun, {
    validate(need(tem_municipios, "Os dados por município ainda não chegaram: falta atualizar o gold."))
    doenca <- validar(input$doenca_mun, escolhas_doenca)
    uf <- validar(input$uf_mun, escolhas_uf)
    periodo <- as.integer(validar(input$periodo_mun, anos_disponiveis))
    anos <- intersect(seq(min(periodo), max(periodo)), anos_da_doenca(doenca))
    validate(need(length(anos) > 0, "Não há dados dessa doença no período escolhido."))
    por <- if (doenca %in% DOENCAS_SO_CASOS) "casos" else validar(input$tipo_mun, c("incidencia", "casos"))
    # Município buscado: só vale se for da UF escolhida (logo depois de trocar a
    # UF, a lista do campo ainda pode ser a da UF anterior)
    mun <- input$municipio_mun
    mun <- if (length(mun) == 1 && mun %in% malha_municipios(uf)$municipio) mun else NULL
    list(doenca = doenca, uf = uf, anos = anos, por = por, municipio = mun, dados = dados_municipios(doenca, uf, anos))
  }, ignoreNULL = FALSE)

  output$mun_titulo <- renderUI({
    r <- municipal()
    titulo_municipios(r$dados, r$doenca, r$uf, r$anos, r$por, r$municipio)
  })
  output$mapa_mun <- renderLeaflet({
    r <- municipal()
    grafico_mapa_mun(r$dados, r$doenca, r$uf, r$anos, r$por, r$municipio)
  })
  output$ranking_mun <- renderHighchart({
    r <- municipal()
    grafico_ranking_mun(r$dados, r$doenca, r$uf, r$anos, r$por, r$municipio)
  })
  output$nota_mun <- renderUI({
    r <- municipal()
    sem <- attr(r$dados, "sem_municipio")
    nota_doenca(r$doenca, c(
      if (r$doenca %in% DOENCAS_SO_CASOS) "Raiva: só casos, sem incidência (são poucos casos por ano no país todo)."
      else if (r$por == "incidencia") paste(
        "Com mais de um ano, a taxa é a média anual: casos do período ÷ soma das populações dos anos × 100 mil.",
        "Em município pequeno, poucos casos mudam muito a taxa (1 caso em 5 mil habitantes já é 20 por 100 mil);",
        "somar anos deixa a taxa mais estável."),
      paste("Cores pelos quintis dos municípios com casos. Município de residência.",
            "População dos municípios: Contagem 2007, Censos 2010 e 2022 e estimativas do IBGE, ajustadas à projeção da UF."),
      if (sem > 0) paste(formatar_numero(sem), "caso(s) com município de residência ignorado não aparecem no mapa nem no ranking.")
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
