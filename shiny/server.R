# Server. Os dados e os cálculos ficam em dados.R; aqui só entram a interface
# e os gráficos. Cada gráfico é recalculado ao clicar em "Atualizar plot"
# (e uma vez na abertura, com os valores padrão).

OKABE_ITO <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999")
COR_SEXO <- c(M = "#049899", F = "#ed9400")
COR_RACA <- c("1" = "#56B4E9", "2" = "#0072B2", "3" = "#F0E442", "4" = "#E69F00", "5" = "#009E73", "9" = "#999999")
COR_REGIAO <- c("Norte" = "#009E73", "Nordeste" = "#E69F00", "Sudeste" = "#0072B2", "Sul" = "#CC79A7", "Centro-Oeste" = "#D55E00")

# Faixa cinza nos anos preliminares. Com `categorias` (eixo de categorias do
# highcharter), a posição é o índice do ano, não o ano.
faixa_preliminar <- function(doenca, categorias = NULL) {
  prelim <- arquivos$ano[arquivos$doenca == doenca & arquivos$status == "PRELIM"]
  if (!length(prelim)) return(list())
  pos <- if (is.null(categorias)) prelim else match(prelim, categorias) - 1
  list(list(from = min(pos) - 0.5, to = max(pos) + 0.5, color = "rgba(0,0,0,0.05)",
            label = list(text = "preliminar", style = list(color = "#888"))))
}

server <- function(input, output, session) {

  #Série temporal----
  serie <- eventReactive(input$update_st, {
    doenca <- validar(input$doenca_st, escolhas_doenca)
    ufs_sel <- validar(input$uf_st, escolhas_uf_brasil)
    sexos <- validar(input$sexo, SEXOS)
    faixas <- validar(input$faixa_etaria, c("Todos", FAIXAS))
    linhas <- list()
    for (u in ufs_sel) for (s in sexos) {
      d <- serie_incidencia(doenca, u, s, faixas)
      d$serie <- paste(nome_uf(u), rotulo_sexo(s), sep = ", ")
      linhas[[length(linhas) + 1]] <- d
    }
    list(doenca = doenca, dados = do.call(rbind, linhas))
  }, ignoreNULL = FALSE)

  output$monthplot <- renderHighchart({
    r <- serie()
    hchart(r$dados, "line", hcaes(x = ano, y = incidencia, group = serie)) |>
      hc_colors(OKABE_ITO) |>
      hc_title(text = paste("Incidência de", nome_doenca(r$doenca))) |>
      hc_xAxis(title = list(text = "Ano"), allowDecimals = FALSE, plotBands = faixa_preliminar(r$doenca)) |>
      hc_yAxis(title = list(text = "Taxa de incidência por 100 mil habitantes"), min = 0) |>
      hc_tooltip(shared = TRUE, crosshairs = TRUE, valueDecimals = 2) |>
      hc_legend(title = list(text = "UF, Sexo")) |>
      hc_exporting(enabled = TRUE)
  })
  output$nota_st <- renderUI(nota_doenca(serie()$doenca))

  #Pirâmide etária----
  piramide <- eventReactive(input$update_pe, {
    doenca <- validar(input$doenca_pe, escolhas_doenca)
    uf <- validar(input$uf_pe, escolhas_uf_brasil)
    ano <- as.integer(validar(input$ano_pe, as.character(anos_disponiveis)))
    list(doenca = doenca, uf = uf, ano = ano, dados = dados_piramide(doenca, uf, ano))
  }, ignoreNULL = FALSE)

  output$piram_et <- renderPlotly({
    r <- piramide()
    d <- r$dados
    validate(need(sum(d$casos) > 0, "Não há casos para esse conjunto de filtros."))
    m <- d[d$sexo == "M", ]
    f <- d[d$sexo == "F", ]
    marcas <- pretty(c(0, max(d$casos)), n = 4)
    marcas <- c(-rev(marcas[-1]), marcas)
    plot_ly() |>
      add_bars(data = m, x = ~-casos, y = ~faixa_etaria, orientation = "h", name = "Masculino",
               marker = list(color = COR_SEXO[["M"]]), text = ~formatar_numero(casos),
               hovertemplate = "%{y}: %{text} casos<extra>Masculino</extra>", textposition = "none") |>
      add_bars(data = f, x = ~casos, y = ~faixa_etaria, orientation = "h", name = "Feminino",
               marker = list(color = COR_SEXO[["F"]]), text = ~formatar_numero(casos),
               hovertemplate = "%{y}: %{text} casos<extra>Feminino</extra>", textposition = "none") |>
      layout(
        barmode = "overlay", bargap = 0.1,
        title = sprintf("Pirâmide etária de %s, %s, %d", nome_doenca(r$doenca), nome_uf(r$uf), r$ano),
        xaxis = list(title = "Casos", tickvals = marcas, ticktext = formatar_numero(abs(marcas))),
        yaxis = list(title = "Faixa etária", categoryorder = "array", categoryarray = FAIXAS),
        legend = list(title = list(text = "Sexo"))
      )
  })
  output$nota_pe <- renderUI({
    r <- piramide()
    sem <- attr(r$dados, "sem_idade")
    nota_doenca(r$doenca, if (sem > 0) paste(formatar_numero(sem), "caso(s) com idade ignorada não aparecem na pirâmide."))
  })

  #Gráfico de barras----
  barras <- eventReactive(input$update_ed, {
    doenca <- validar(input$doenca_ed, escolhas_doenca)
    uf <- validar(input$uf_ed, escolhas_uf_brasil)
    por <- validar(input$dist_ed, c("sexo", "raca"))
    list(doenca = doenca, uf = uf, por = por, dados = dados_barras(doenca, uf, por))
  }, ignoreNULL = FALSE)

  output$barplot_porcentagem <- renderHighchart({
    r <- barras()
    d <- r$dados
    serie_grupo <- function(g) lapply(which(d$grupo == g), function(i) list(y = d$porcentagem[i], casos = formatar_numero(d$casos[i])))
    grupos <- if (r$por == "sexo") c("M" = "Masculino", "F" = "Feminino") else RACAS
    cores <- if (r$por == "sexo") COR_SEXO else COR_RACA
    hc <- highchart() |>
      hc_chart(type = "column") |>
      hc_xAxis(categories = unique(d$ano), title = list(text = "Ano"), plotBands = faixa_preliminar(r$doenca, unique(d$ano))) |>
      hc_yAxis(title = list(text = "Porcentagem"), labels = list(format = "{value}%"), max = 100) |>
      hc_plotOptions(column = list(stacking = "normal", reversedStacks = FALSE,
                                   dataLabels = list(enabled = r$por == "sexo", format = "{point.y:.1f}%")))
    for (g in names(grupos)) hc <- hc |> hc_add_series(data = serie_grupo(g), name = grupos[[g]], color = cores[[g]])
    hc |>
      hc_tooltip(shared = FALSE, headerFormat = "<b>{point.key}</b><br>",
                 pointFormat = "{series.name}: {point.casos} casos ({point.y:.1f}%)") |>
      hc_title(text = paste0("Distribuição percentual de casos de ", nome_doenca(r$doenca), " por ",
                             if (r$por == "sexo") "sexo" else "raça/cor", ", ", nome_uf(r$uf))) |>
      hc_exporting(enabled = TRUE)
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
    hchart(r$dados, "line", hcaes(x = inicio_semana, y = casos, group = uf)) |>
      hc_colors(OKABE_ITO) |>
      hc_title(text = paste("Casos de", nome_doenca(r$doenca), "por semana epidemiológica de início dos sintomas")) |>
      hc_xAxis(title = list(text = "Semana (data de início)"), type = "datetime") |>
      hc_yAxis(title = list(text = "Casos"), min = 0) |>
      hc_tooltip(shared = TRUE, crosshairs = TRUE, xDateFormat = "Semana de %d/%m/%Y") |>
      hc_plotOptions(series = list(marker = list(enabled = FALSE))) |>
      hc_legend(title = list(text = "UF")) |>
      hc_exporting(enabled = TRUE)
  })
  output$nota_sem <- renderUI(nota_doenca(semanal()$doenca, paste(
    "Semana epidemiológica de início dos sintomas (domingo a sábado), não ano de notificação: os totais",
    "podem diferir um pouco das outras abas. As semanas mais recentes ficam incompletas até as notificações",
    "serem digitadas. Hanseníase e leishmaniose tegumentar não têm esse campo.")))

  #Mapas----
  mapa <- eventReactive(input$update_map, {
    doenca <- validar(input$doenca_map, escolhas_doenca)
    ano <- as.integer(validar(input$ano_map, as.character(anos_disponiveis)))
    tipo <- validar(input$tipo_mapa, c("Casos Absolutos", "Incidência"))
    list(doenca = doenca, ano = ano, tipo = tipo, dados = dados_mapa(doenca, ano))
  }, ignoreNULL = FALSE)

  output$mapa_incid <- renderLeaflet({
    r <- mapa()
    m <- r$dados
    absoluto <- r$tipo == "Casos Absolutos"
    valor <- if (absoluto) m$casos else m$incidencia
    pal <- colorBin("YlOrRd", domain = c(0, max(valor, 1, na.rm = TRUE)), bins = 7, pretty = TRUE)
    rotulo <- if (absoluto) {
      paste0(m$NM_UF, ": ", formatar_numero(m$casos), " casos")
    } else {
      paste0(m$NM_UF, ": ", formatar_numero(m$incidencia, 2), " por 100 mil hab. (", formatar_numero(m$casos), " casos)")
    }
    titulo <- paste0(if (absoluto) "Casos" else "Incidência", " de ", nome_doenca(r$doenca), ", ", r$ano)
    leaflet(m, options = leafletOptions(minZoom = 3, maxZoom = 10)) |>
      setView(lng = -54, lat = -15, zoom = 4) |>
      addTiles() |>
      addControl(tags$b(titulo), position = "topright") |>
      addPolygons(
        fillColor = pal(valor), weight = 1.5, opacity = 1, color = "white", fillOpacity = 0.75,
        highlightOptions = highlightOptions(weight = 3, color = "#666", fillOpacity = 0.85, bringToFront = TRUE),
        label = rotulo,
        labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px"), textsize = "14px")
      ) |>
      addLegend(pal = pal, values = valor, opacity = 0.75, position = "bottomright",
                title = if (absoluto) "Casos" else "Por 100 mil hab.",
                labFormat = labelFormat(big.mark = "."))
  })
  output$nota_map <- renderUI({
    r <- mapa()
    sem <- attr(r$dados, "sem_uf")
    nota_doenca(r$doenca, if (sem > 0) paste(formatar_numero(sem), "caso(s) com UF de residência ignorada não aparecem no mapa."))
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
    d <- r$dados
    d$texto <- paste0(d$sigla, "  ", formatar_numero(d$valor, if (r$tipo == "Incidência") 2 else 0))
    p <- plot_ly(d, x = ~valor, y = ~posicao, frame = ~ano, ids = ~sigla, type = "bar", orientation = "h",
            marker = list(color = unname(COR_REGIAO[d$regiao])), text = ~texto, textposition = "outside",
            hovertemplate = "%{text}<extra></extra>", cliponaxis = FALSE) |>
      layout(
        title = paste0(if (r$tipo == "Incidência") "Incidência (por 100 mil hab.)" else "Casos",
                       " de ", nome_doenca(r$doenca), ": ranking das UFs"),
        yaxis = list(autorange = "reversed", showticklabels = FALSE, title = "", dtick = 1),
        xaxis = list(title = if (r$tipo == "Incidência") "Por 100 mil habitantes" else "Casos"),
        margin = list(r = 40),
        showlegend = FALSE
      ) |>
      animation_opts(frame = 900, transition = 500, redraw = FALSE) |>
      animation_slider(currentvalue = list(prefix = "Ano: "))
    # Eixo x de cada ano no máximo daquele ano: com um eixo só (máximo de todos
    # os anos), um ano de epidemia achata as barras dos outros.
    p <- plotly_build(p)
    maximos <- tapply(d$valor, d$ano, max)
    primeiro <- names(maximos)[1]
    for (i in seq_along(p$x$frames)) {
      m <- maximos[[p$x$frames[[i]]$name]]
      p$x$frames[[i]]$layout <- list(xaxis = list(range = c(0, max(m, 1e-9) * 1.18)))
    }
    p$x$layout$xaxis$range <- c(0, max(maximos[[primeiro]], 1e-9) * 1.18)
    p
  })
  output$nota_br <- renderUI({
    regioes <- lapply(names(COR_REGIAO), function(n) tags$span(style = paste0("color:", COR_REGIAO[[n]], ";font-weight:bold"), n))
    legenda <- tagList("Cores por região: ", do.call(tagList, utils::head(rbind(regioes, list(", ")), -1)))
    nota_doenca(corrida()$doenca, legenda)
  })
}
