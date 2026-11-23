# Gráficos do app. Cada função recebe os dados já calculados (dados.R) e devolve
# o widget pronto; server.R só liga os filtros a elas.
#
# As regras vêm da skill present-with-data e do design system "Gabriel — Data
# Decks", no estilo neutro (cores em global.R):
#   - título que diz o que o gráfico mostra (ou a conclusão, quando ela sai dos
#     próprios dados, como na tendência e no ranking) e subtítulo com unidade,
#     período e definição;
#   - nome da série escrito no fim da linha, em vez de legenda;
#   - cor só no que importa, o resto em cinza; mesma cor para o mesmo grupo em
#     todas as abas (sexo, por exemplo);
#   - mapa só com taxa (nunca contagem bruta) e faixas pelos quintis;
#   - mesma casa decimal dentro de cada gráfico; fonte do dado no rodapé e, na
#     imagem exportada, no próprio gráfico.

# ---- formatação -------------------------------------------------------------

MENOS <- "−"

#' Número com sinal explícito e o "−" tipográfico.
com_sinal <- function(x, digitos = 1) {
  paste0(ifelse(x > 0, "+", ifelse(x < 0, MENOS, "")), formatar_numero(abs(x), digitos))
}

#' Casas decimais de uma taxa, iguais em todo o gráfico: 1 a partir de 100,
#' 2 a partir de 1 e 3 abaixo disso (raiva, por exemplo).
casas_taxa <- function(x) {
  m <- suppressWarnings(max(abs(x), na.rm = TRUE))
  if (!is.finite(m) || m >= 100) 1 else if (m >= 1) 2 else 3
}

#' Espaço à direita para o nome das séries no fim das linhas.
margem_rotulos <- function(nomes) min(260, ceiling(max(nchar(nomes)) * 7.6 + 24))

#' Período para título, sem vírgula: "em 2025" ou "de 2007 a 2026".
periodo_titulo <- function(anos) {
  anos <- range(anos)
  if (anos[1] == anos[2]) paste("em", anos[1]) else paste0("de ", anos[1], " a ", anos[2])
}

# Preposição de cada UF ("no Acre", "na Bahia", "em São Paulo")
PREPOSICAO_UF <- c(
  "Brasil" = "no", "Acre" = "no", "Alagoas" = "em", "Amapá" = "no", "Amazonas" = "no", "Bahia" = "na",
  "Ceará" = "no", "Distrito Federal" = "no", "Espírito Santo" = "no", "Goiás" = "em", "Maranhão" = "no",
  "Mato Grosso" = "em", "Mato Grosso do Sul" = "em", "Minas Gerais" = "em", "Pará" = "no", "Paraíba" = "na",
  "Paraná" = "no", "Pernambuco" = "em", "Piauí" = "no", "Rio de Janeiro" = "no", "Rio Grande do Norte" = "no",
  "Rio Grande do Sul" = "no", "Rondônia" = "em", "Roraima" = "em", "Santa Catarina" = "em", "São Paulo" = "em",
  "Sergipe" = "em", "Tocantins" = "no"
)

#' Lugar para título: "no Brasil", "em São Paulo", "na Bahia".
lugar_titulo <- function(uf) {
  nome <- nome_uf(uf)
  prep <- PREPOSICAO_UF[nome]
  paste(if (is.na(prep)) "em" else prep, nome)
}

periodo_anos <- function(anos) {
  anos <- range(anos)
  if (anos[1] == anos[2]) as.character(anos[1]) else paste0(anos[1], "–", anos[2])
}

data_coleta <- function(doenca) {
  a <- arquivos[arquivos$doenca == doenca, ]
  format(as.Date(substr(max(a$data_coleta), 1, 10)), "%d/%m/%Y")
}

MESES <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
mes_ano <- function(d) paste0(MESES[as.integer(format(d, "%m"))], "/", format(d, "%Y"))

anos_finais <- function(doenca) sort(arquivos$ano[arquivos$doenca == doenca & arquivos$status == "FINAL"])

# ---- peças comuns ----------------------------------------------------------

#' Faixa cinza nos anos preliminares. Com `categorias` (eixo de categorias), a
#' posição é o índice do ano; com `datas = TRUE` (eixo de datas), vai de 1º de
#' janeiro a 31 de dezembro, em milissegundos.
faixa_preliminar <- function(doenca, categorias = NULL, datas = FALSE) {
  prelim <- arquivos$ano[arquivos$doenca == doenca & arquivos$status == "PRELIM"]
  if (!length(prelim)) return(list())
  if (datas) {
    ms <- function(d) as.numeric(as.POSIXct(d, tz = "UTC")) * 1000
    de <- ms(sprintf("%d-01-01", min(prelim)))
    ate <- ms(sprintf("%d-12-31", max(prelim)))
  } else {
    pos <- if (is.null(categorias)) prelim else match(prelim, categorias) - 1
    pos <- pos[!is.na(pos)]
    if (!length(pos)) return(list())
    de <- min(pos) - 0.5
    ate <- max(pos) + 0.5
  }
  list(list(from = de, to = ate, color = "rgba(148, 163, 184, 0.15)", zIndex = 0,
            label = list(text = "Preliminar", align = "right", x = -4, y = 14,
                         style = list(color = CORES$tinta_suave, fontSize = "12px", textOverflow = "none",
                                      whiteSpace = "nowrap"))))
}

#' Exportação com a fonte do dado escrita no gráfico (a imagem sai da página e
#' precisa se explicar sozinha).
exportacao <- function(hc, doenca, arquivo) {
  hc_exporting(
    hc, enabled = TRUE, filename = paste0("vigitrop_", arquivo),
    sourceWidth = 960, sourceHeight = 540,
    chartOptions = list(credits = list(
      enabled = TRUE, href = NULL,
      text = paste0("Fonte: SINAN/DataSUS (coleta em ", data_coleta(doenca), ") e projeção IBGE 2024. VigiTrop, UNIFESP."),
      position = list(align = "left", x = 10, y = -6),
      style = list(color = CORES$tinta_suave, fontSize = "11px")
    ))
  )
}

#' Marca o pico de uma série (receita 3): ponto escuro, rótulo curto em negrito
#' e o valor em cinza embaixo.
marcar_pico <- function(pontos, rotulo, valor) {
  k <- which.max(vapply(pontos, function(p) p$y, numeric(1)))
  if (!length(k) || pontos[[k]]$y <= 0) return(pontos)
  pontos[[k]]$marker <- list(enabled = TRUE, radius = 5, fillColor = CORES$tinta, lineWidth = 0)
  # Perto das pontas, o rótulo vai para dentro (no celular ele saía do gráfico)
  pos <- k / length(pontos)
  pontos[[k]]$dataLabels <- list(
    enabled = TRUE, crop = FALSE, overflow = "allow", y = -6,
    align = if (pos > 0.75) "right" else if (pos < 0.25) "left" else "center",
    x = if (pos > 0.75) 6 else if (pos < 0.25) -6 else 0,
    format = sprintf('<span style="font-weight:600">%s</span><br/><span style="color:%s">%s</span>',
                     rotulo, CORES$tinta_suave, valor)
  )
  pontos
}

linha_base <- function(valor = 0) list(list(value = valor, color = CORES$tinta, width = 1, zIndex = 3))

#' Versão para celular (regra "responsive" do Highcharts, aplicada pelo próprio
#' navegador quando o gráfico fica estreito, e desfeita ao girar a tela):
#' legenda no alto no lugar dos nomes no fim das linhas (VT.rotulosFinais não os
#' desenha com a legenda ligada), sem título no eixo y e títulos menores.
#' `extra` acrescenta ou troca opções nessa versão.
compacto <- function(hc, extra = list(), largura = 520) {
  base <- list(
    chart = list(marginRight = 8),
    title = list(style = list(fontSize = "16px")),
    subtitle = list(style = list(fontSize = "13px")),
    legend = list(enabled = TRUE, align = "left", verticalAlign = "top", x = 0, margin = 8),
    xAxis = list(labels = list(rotation = 0)),
    yAxis = list(title = list(text = ""))
  )
  hc_responsive(hc, rules = list(list(condition = list(maxWidth = largura),
                                      chartOptions = utils::modifyList(base, extra))))
}

#' Faixa dos preliminares sem o texto "Preliminar" (no celular ele cai em cima
#' do rótulo do pico).
sem_rotulo <- function(bandas) lapply(bandas, function(b) { b$label <- NULL; b })

# ---- série temporal ----------------------------------------------------------

#' Incidência anual ou mensal de uma ou mais séries (UF × sexo).
grafico_serie <- function(dados, doenca, mensal, detalhe = NULL) {
  nomes <- unique(dados$serie)
  casas <- casas_taxa(dados$incidencia)
  um <- length(nomes) == 1
  hc <- highchart() |>
    hc_chart(type = "line", marginRight = margem_rotulos(nomes), events = list(render = JS("VT.rotulosFinais")))
  for (i in seq_along(nomes)) {
    d <- dados[dados$serie == nomes[i], ]
    x <- if (mensal) datetime_to_timestamp(d$mes) else d$ano
    pontos <- list_parse(data.frame(x = x, y = d$incidencia, casos = formatar_numero(d$casos)))
    if (um) {
      quando <- if (mensal) mes_ano(d$mes[which.max(d$incidencia)]) else d$ano[which.max(d$incidencia)]
      pontos <- marcar_pico(pontos, paste("Pico em", quando), formatar_numero(max(d$incidencia), casas))
    }
    hc <- hc |> hc_add_series(data = pontos, name = nomes[i], color = PALETA[(i - 1) %% length(PALETA) + 1],
                              lineWidth = if (um) 3 else 2.5)
  }
  sub <- paste0(if (mensal) "Casos notificados no mês por 100 mil habitantes" else "Casos por 100 mil habitantes, por ano de notificação",
                if (length(detalhe)) paste0(". ", detalhe) else "")
  bandas <- if (mensal) faixa_preliminar(doenca, datas = TRUE) else faixa_preliminar(doenca)
  eixo_x <- if (mensal) {
    list(type = "datetime", plotBands = bandas, dateTimeLabelFormats = list(month = "%b/%Y", year = "%Y"))
  } else {
    list(allowDecimals = FALSE, plotBands = bandas)
  }
  hc |>
    hc_title(text = paste0("Incidência ", if (mensal) "mensal " else "", "de ", nome_doenca(doenca), " ",
                           if (mensal) paste0("de ", mes_ano(min(dados$mes)), " a ", mes_ano(max(dados$mes)))
                           else periodo_titulo(dados$ano))) |>
    hc_subtitle(text = sub) |>
    hc_xAxis(eixo_x) |>
    hc_yAxis(min = 0, title = list(text = "por 100 mil hab."), plotLines = linha_base()) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(shared = TRUE, crosshairs = TRUE, xDateFormat = "%b/%Y", headerFormat = "<b>{point.key}</b><br/>",
               pointFormat = paste0('<span style="color:{series.color}">●</span> {series.name}: <b>{point.y:,.',
                                    casas, 'f}</b> ({point.casos} casos)<br/>')) |>
    compacto(list(xAxis = c(list(plotBands = sem_rotulo(bandas)), if (!mensal) list(tickInterval = 5)))) |>
    exportacao(doenca, "serie")
}

# ---- série semanal -------------------------------------------------------

grafico_semanal <- function(dados, doenca) {
  nomes <- unique(dados$uf)
  um <- length(nomes) == 1
  hc <- highchart() |>
    hc_chart(type = "line", marginRight = margem_rotulos(nomes), events = list(render = JS("VT.rotulosFinais")))
  for (i in seq_along(nomes)) {
    d <- dados[dados$uf == nomes[i], ]
    pontos <- list_parse(data.frame(x = datetime_to_timestamp(d$inicio_semana), y = d$casos))
    if (um) {
      pontos <- marcar_pico(pontos, paste("Pico na semana de", format(d$inicio_semana[which.max(d$casos)], "%d/%m/%Y")),
                            paste(formatar_numero(max(d$casos)), "casos"))
    }
    hc <- hc |> hc_add_series(data = pontos, name = nomes[i], color = PALETA[(i - 1) %% length(PALETA) + 1],
                              lineWidth = if (um) 2.5 else 2)
  }
  anos <- as.integer(format(range(dados$inicio_semana), "%Y"))
  bandas <- faixa_preliminar(doenca, datas = TRUE)
  hc |>
    hc_title(text = paste0("Casos de ", nome_doenca(doenca), " por semana epidemiológica ", periodo_titulo(anos))) |>
    hc_subtitle(text = "Casos por semana de início dos sintomas. As semanas mais recentes ainda estão incompletas.") |>
    hc_xAxis(type = "datetime", plotBands = bandas,
             dateTimeLabelFormats = list(week = "%d/%m/%Y", month = "%b/%Y", year = "%Y")) |>
    hc_yAxis(min = 0, title = list(text = "casos por semana"), plotLines = linha_base()) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(shared = TRUE, crosshairs = TRUE, xDateFormat = "Semana de %d/%m/%Y",
               headerFormat = "<b>{point.key}</b><br/>",
               pointFormat = '<span style="color:{series.color}">●</span> {series.name}: <b>{point.y:,.0f}</b> casos<br/>') |>
    compacto(list(xAxis = list(plotBands = sem_rotulo(bandas)))) |>
    exportacao(doenca, "semanal")
}

# ---- distribuição por sexo e por raça/cor --------------------------------

#' Sexo ou raça/cor: colunas 100% empilhadas, uma por ano, com o nome de cada
#' grupo ao lado da última coluna (sem legenda). No sexo, o valor vai dentro da
#' coluna e a linha tracejada marca 50%; na raça/cor, que tem fatias finas, o
#' valor fica no tooltip.
grafico_barras <- function(d, doenca, uf, por = c("sexo", "raca")) {
  por <- match.arg(por)
  sexo <- por == "sexo"
  grupos <- if (sexo) c(M = "Masculino", F = "Feminino") else RACAS
  cores <- if (sexo) COR_SEXO else COR_RACA
  # Cores claras não dão contraste como texto: nelas o nome vai em cinza-escuro
  cor_texto <- if (sexo) COR_SEXO else COR_RACA_TEXTO
  anos <- sort(unique(d$ano))
  prelim <- setdiff(anos, anos_finais(doenca))
  rotulos <- ifelse(anos %in% prelim, paste0(anos, "*"), anos)
  hc <- highchart(height = 600) |>
    hc_chart(type = "column", marginRight = margem_rotulos(grupos), events = list(render = JS("VT.rotulosFinais")))
  for (g in names(grupos)) {
    x <- d[d$grupo == g, ]
    x <- x[match(anos, x$ano), ]
    hc <- hc |> hc_add_series(
      data = list_parse(data.frame(y = x$porcentagem, casos = formatar_numero(ifelse(is.na(x$casos), 0, x$casos)))),
      name = grupos[[g]], color = cores[[g]], vtCorRotulo = cor_texto[[g]]
    )
  }
  hc |>
    hc_plotOptions(column = list(stacking = "normal", pointPadding = 0.08, groupPadding = 0,
                                 dataLabels = list(enabled = sexo, format = "{point.y:.0f}%",
                                                   style = list(color = "#FFFFFF", fontSize = "12px", fontWeight = "500")))) |>
    hc_title(text = paste0("Casos de ", nome_doenca(doenca), " por ", if (sexo) "sexo" else "raça/cor", " ",
                           lugar_titulo(uf), " ", periodo_titulo(anos))) |>
    hc_subtitle(text = paste0("% dos casos de cada ano.",
                              if (sexo) " Casos com sexo ignorado ficam fora da conta." else " Raça/cor em branco entra como Ignorada.",
                              if (length(prelim)) " * Dados preliminares." else "")) |>
    hc_xAxis(categories = rotulos, labels = list(autoRotation = FALSE, step = 1)) |>
    # Na raça/cor, a primeira série (Branca) vai embaixo e "Ignorada" no topo
    hc_yAxis(max = 100, tickInterval = 25, labels = list(format = "{value}%"), title = list(text = ""),
             reversedStacks = sexo,
             plotLines = if (sexo) list(list(value = 50, color = CORES$tinta, width = 1, dashStyle = "Dash", zIndex = 5))) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(headerFormat = "<b>{point.key}</b><br/>", pointFormat = "{series.name}: {point.casos} casos ({point.y:.1f}%)") |>
    # No celular, 20 colunas não cabem: as barras deitam (um ano por linha)
    compacto(list(chart = list(inverted = TRUE, marginRight = 24), legend = list(reversed = sexo),
                  yAxis = list(labels = list(rotation = 0), tickInterval = 50))) |>
    exportacao(doenca, if (sexo) "sexo" else "raca_cor")
}

#' Raça/cor: um painel por grupo (receita 14), mesma escala em todos. Em cada
#' painel, o grupo em azul e os outros em cinza; a manchete dá o valor do último
#' ano fechado e a variação desde o primeiro ano.
paineis_raca <- function(d, doenca, uf) {
  anos <- sort(unique(d$ano))
  finais <- intersect(anos_finais(doenca), anos)
  ref <- if (length(finais)) max(finais) else max(anos)
  ordem <- d[d$ano == ref & d$grupo != "9", ]
  ordem <- c(ordem$grupo[order(-ordem$porcentagem)], "9")
  teto <- ceiling(max(d$porcentagem, na.rm = TRUE) / 10) * 10
  bandas <- faixa_preliminar(doenca, anos)
  if (length(bandas)) bandas[[1]]$label <- NULL

  painel <- function(g) {
    foco <- d[d$grupo == g, ]
    inicio <- foco$porcentagem[foco$ano == min(anos)]
    fim <- foco$porcentagem[foco$ano == ref]
    delta <- round(fim) - round(inicio)
    manchete <- if (is.na(fim)) "Sem casos" else paste0(
      formatar_numero(fim, 0), "% em ", ref, " · ",
      if (is.na(inicio)) "" else if (delta == 0) paste("igual a", min(anos)) else paste(com_sinal(delta, 0), "p.p. desde", min(anos))
    )
    hc <- highchart(height = 235) |>
      hc_chart(type = "line", spacing = list(8, 8, 8, 0)) |>
      hc_xAxis(categories = anos, plotBands = bandas, tickInterval = max(1, ceiling(length(anos) / 4)), labels = list(step = 1)) |>
      hc_yAxis(min = 0, max = teto, tickAmount = 3, labels = list(format = "{value}%"), title = list(text = "")) |>
      hc_legend(enabled = FALSE) |>
      hc_tooltip(headerFormat = "<b>{point.key}</b><br/>", pointFormat = "{series.name}: {point.y:.1f}% ({point.casos} casos)")
    for (o in setdiff(names(RACAS), g)) {
      hc <- hc |> hc_add_series(data = d$porcentagem[d$grupo == o], name = RACAS[[o]], color = CORES$contexto,
                                lineWidth = 1.25, opacity = 0.5, enableMouseTracking = FALSE, zIndex = 1)
    }
    hc <- hc |> hc_add_series(data = list_parse(data.frame(y = foco$porcentagem, casos = formatar_numero(foco$casos))),
                              name = RACAS[[g]], color = CORES$destaque, lineWidth = 3, zIndex = 2)
    tags$div(class = "vt-painel",
             tags$p(class = "vt-painel-nome", RACAS[[g]]),
             tags$p(class = "vt-painel-manchete", manchete),
             hc)
  }
  tags$div(
    class = "vt-bloco",
    tags$p(class = "vt-titulo", paste0("Casos de ", nome_doenca(doenca), " por raça/cor ", lugar_titulo(uf), " ", periodo_titulo(anos))),
    tags$p(class = "vt-subtitulo",
           "% dos casos de cada ano. Em cada painel, a linha azul é o grupo do painel e as cinzas, os demais; todos na mesma escala.",
           if (length(bandas)) " A faixa cinza marca os anos preliminares."),
    tags$div(class = "vt-grade-paineis", lapply(ordem, painel))
  )
}

# ---- pirâmide etária -----------------------------------------------------

grafico_piramide <- function(d, doenca, uf, ano) {
  total <- sum(d$casos)
  pct_f <- 100 * sum(d$casos[d$sexo == "F"]) / total
  serie <- function(s, sinal) {
    x <- d[d$sexo == s, ]
    x <- x[match(FAIXAS, x$faixa_etaria), ]
    list_parse(data.frame(y = sinal * x$casos, casos = formatar_numero(x$casos),
                          pct = formatar_numero(100 * x$casos / total, 1)))
  }
  m <- max(d$casos)
  marcas <- pretty(c(0, m), n = 3)
  marcas <- marcas[marcas <= m * 1.08]
  marcas <- c(-rev(marcas[-1]), marcas)
  # No celular, só três marcas no eixo (sem elas, os rótulos ficam inclinados)
  poucas <- pretty(c(0, m), n = 2)
  poucas <- poucas[poucas <= m * 1.08]
  poucas <- c(-rev(poucas[-1]), poucas)
  highchart() |>
    hc_chart(type = "bar", events = list(render = JS("VT.rotulosLados"))) |>
    hc_add_series(data = serie("M", -1), name = "Masculino", color = COR_SEXO[["M"]]) |>
    hc_add_series(data = serie("F", 1), name = "Feminino", color = COR_SEXO[["F"]]) |>
    hc_plotOptions(series = list(stacking = "normal", pointPadding = 0.06, groupPadding = 0)) |>
    hc_xAxis(categories = FAIXAS, reversed = FALSE, labels = list(step = 1), lineWidth = 0, tickLength = 0) |>
    hc_yAxis(min = -m * 1.08, max = m * 1.08, tickPositions = marcas, endOnTick = FALSE, startOnTick = FALSE,
             title = list(text = ""), plotLines = linha_base(),
             labels = list(formatter = JS("VT.rotuloAbs"))) |>
    hc_title(text = paste0("Casos de ", nome_doenca(doenca), " por faixa etária e sexo ", lugar_titulo(uf), " em ", ano)) |>
    hc_subtitle(text = paste0(formatar_numero(total), " casos com sexo e idade conhecidos; ",
                              formatar_numero(pct_f, 0), "% no sexo feminino.")) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(headerFormat = "", pointFormat = "<b>{series.name}, {point.category} anos</b><br/>{point.casos} casos ({point.pct}% do total)") |>
    compacto(list(legend = list(enabled = FALSE), yAxis = list(tickPositions = poucas))) |>
    exportacao(doenca, "piramide")
}

# ---- mapa e ranking das UFs --------------------------------------------------

#' Classes do mapa pelos quintis das UFs com casos (arredondados a 2 algarismos);
#' UF sem casos fica em cinza à parte. Devolve a cor de cada UF e a legenda.
classes_mapa <- function(valor, casas, casos = valor) {
  pos <- valor[is.finite(valor) & casos > 0]
  cor <- rep(COR_SEM_CASOS, length(valor))
  if (!length(pos)) return(list(cor = cor, cores = COR_SEM_CASOS, rotulos = "Sem casos"))
  # Até 5 faixas, mas nunca mais faixas que UFs com casos (raiva: 1 ou 2 UFs)
  k <- min(5, length(unique(pos)))
  q <- signif(stats::quantile(pos, seq(0, 1, length.out = k + 1), names = FALSE), 2)
  # Contagens: faixas de inteiros. Começa em (mínimo − 1), para que um valor
  # muito repetido (raiva: 1 caso) tenha faixa própria.
  cortes <- if (casas == 0) unique(c(min(pos) - 1, round(q[-1]))) else unique(q)
  cortes[1] <- min(cortes[1], min(pos))
  cortes[length(cortes)] <- max(cortes[length(cortes)], max(pos))
  if (length(cortes) < 2) cortes <- c(0, max(pos))
  k <- length(cortes) - 1
  rampa <- RAMPA_MAPA[seq(length(RAMPA_MAPA) - k + 1, length(RAMPA_MAPA))]
  classe <- findInterval(valor, cortes, rightmost.closed = TRUE, left.open = TRUE)
  classe[classe < 1] <- 1
  ok <- is.finite(valor) & casos > 0
  cor[ok] <- rampa[classe[ok]]
  de <- cortes[-(k + 1)]
  ate <- cortes[-1]
  # As faixas são abertas à esquerda: nas contagens, cada uma começa no inteiro
  # seguinte ao corte (ex.: 5.001 – 8.800)
  if (casas == 0) de <- floor(de) + 1
  rotulos <- ifelse(round(de, casas) == round(ate, casas), formatar_numero(ate, casas),
                    paste0(formatar_numero(de, casas), " – ", formatar_numero(ate, casas)))
  if (any(!ok)) list(cor = cor, cores = c(rev(rampa), COR_SEM_CASOS), rotulos = c(rev(rotulos), "Sem casos"))
  else list(cor = cor, cores = rev(rampa), rotulos = rev(rotulos))
}

#' Taxa do Brasil no ano (inclui casos com UF ignorada, como nas outras abas).
taxa_brasil <- function(doenca, ano) {
  s <- serie_incidencia(doenca, BRASIL, "Ambos", "Todos")
  s$incidencia[s$ano == ano]
}

#' Valor do mapa e do ranking (incidência ou casos), com as casas decimais.
valor_mapa <- function(m, por) {
  if (por == "incidencia") list(valor = m$incidencia, casas = casas_taxa(m$incidencia))
  else list(valor = m$casos, casas = 0)
}

titulo_mapa <- function(doenca, ano, m, por = c("incidencia", "casos")) {
  por <- match.arg(por)
  br <- serie_incidencia(doenca, BRASIL, "Ambos", "Todos")
  br <- br[br$ano == ano, ]
  tagList(
    tags$p(class = "vt-titulo", paste0(if (por == "incidencia") "Incidência" else "Casos", " de ",
                                       nome_doenca(doenca), " por UF em ", ano)),
    tags$p(class = "vt-subtitulo", if (por == "incidencia") {
      paste0("Casos por 100 mil habitantes. Brasil: ", formatar_numero(br$incidencia, casas_taxa(m$incidencia)), ".")
    } else {
      paste0("Casos notificados, pela UF de residência. Brasil: ", formatar_numero(br$casos), " casos.")
    })
  )
}

grafico_mapa <- function(m, doenca, ano, por = c("incidencia", "casos")) {
  por <- match.arg(por)
  v <- valor_mapa(m, por)
  cl <- classes_mapa(v$valor, v$casas, m$casos)
  casas_inc <- casas_taxa(m$incidencia)
  rotulo <- paste0("<b>", m$NM_UF, "</b><br/>", formatar_numero(m$casos), " casos<br/>",
                   formatar_numero(m$incidencia, casas_inc), " por 100 mil hab.")
  leaflet(m, options = leafletOptions(minZoom = 3, maxZoom = 8, zoomSnap = 0.25, attributionControl = FALSE)) |>
    fitBounds(-73.5, -33.5, -34.8, 5.2) |>
    addPolygons(
      fillColor = cl$cor, fillOpacity = 1, weight = 1, opacity = 1, color = "#FFFFFF",
      highlightOptions = highlightOptions(weight = 2.5, color = CORES$tinta, bringToFront = TRUE),
      label = lapply(rotulo, htmltools::HTML),
      labelOptions = labelOptions(style = list("font-weight" = "normal", "font-family" = FONTE, padding = "4px 8px"),
                                  textsize = "13px", direction = "auto")
    ) |>
    addLegend(colors = cl$cores, labels = cl$rotulos, opacity = 1, position = "bottomleft",
              title = paste0(if (por == "incidencia") "por 100 mil hab." else "casos",
                             "<br/><span style='font-weight:400'>(quintis das UFs)</span>"))
}

#' Ranking das UFs (receita 1), na cor da classe do mapa: o gráfico também serve
#' de legenda. Por incidência, com a linha do Brasil; por casos, o título diz
#' quanto a primeira UF concentra.
grafico_ranking <- function(m, doenca, ano, por = c("incidencia", "casos")) {
  por <- match.arg(por)
  v <- valor_mapa(m, por)
  m$cor <- classes_mapa(v$valor, v$casas, m$casos)$cor
  m$valor <- v$valor
  m <- sf::st_drop_geometry(m)
  m <- m[order(-m$valor, m$NM_UF), ]
  casas_inc <- casas_taxa(m$incidencia)
  pontos <- list_parse(data.frame(y = m$valor, color = m$cor, rotulo = formatar_numero(m$valor, v$casas),
                                  casos = formatar_numero(m$casos), incid = formatar_numero(m$incidencia, casas_inc)))
  if (por == "incidencia") {
    br <- taxa_brasil(doenca, ano)
    acima <- sum(m$incidencia > br, na.rm = TRUE)
    titulo <- paste0(acima, " das 27 UFs ficaram acima da taxa do Brasil")
    sub <- paste0("Incidência por 100 mil habitantes, ", ano, ". Linha tracejada: Brasil.")
    linhas <- list(list(value = br, color = CORES$tinta, width = 1.5, dashStyle = "Dash", zIndex = 2,
                        label = list(text = paste("Brasil", formatar_numero(br, casas_inc)), rotation = 0, align = "left",
                                     verticalAlign = "bottom", x = 4, y = -4,
                                     style = list(color = CORES$tinta, fontWeight = "600", fontSize = "13px"))))
  } else {
    total <- sum(m$casos)
    titulo <- if (total > 0) paste0(m$NM_UF[1], " teve ", formatar_numero(100 * m$casos[1] / total, 0), "% dos casos") else "Nenhum caso no ano"
    sub <- paste0("Casos em ", ano, ", pela UF de residência.")
    linhas <- list()
  }
  highchart() |>
    hc_chart(type = "bar") |>
    hc_add_series(data = pontos, name = if (por == "incidencia") "Incidência" else "Casos",
                  dataLabels = list(enabled = TRUE, format = "{point.rotulo}", crop = FALSE, overflow = "allow",
                                    zIndex = 6, style = list(fontSize = "12px", textOutline = "3px #FFFFFF"))) |>
    hc_plotOptions(bar = list(pointPadding = 0.12, groupPadding = 0, borderWidth = 0)) |>
    hc_xAxis(categories = m$NM_UF, lineColor = CORES$tinta, tickLength = 0, labels = list(step = 1, style = list(fontSize = "12px"))) |>
    # Folga à direita para o rótulo da maior barra (ex.: 890.805) não cortar
    hc_yAxis(min = 0, maxPadding = 0.22, gridLineWidth = 0, labels = list(enabled = FALSE), title = list(text = ""),
             plotLines = linhas) |>
    hc_title(text = titulo, style = list(fontSize = "16px")) |>
    hc_subtitle(text = sub, style = list(fontSize = "13px")) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(headerFormat = "<b>{point.key}</b><br/>",
               pointFormat = "{point.casos} casos<br/>{point.incid} por 100 mil hab.") |>
    # No celular, sigla no lugar do nome (os nomes longos eram cortados). O
    # limite é menor que o dos outros gráficos: no computador o ranking já é
    # estreito (fica ao lado do mapa).
    compacto(list(legend = list(enabled = FALSE), xAxis = list(categories = m$SIGLA_UF)), largura = 380) |>
    exportacao(doenca, "ranking_ufs")
}

# ---- municípios -------------------------------------------------------------
# Mesma leitura do mapa das UFs (quintis dos municípios com casos, ranking ao
# lado), uma UF por vez. Com mais de um ano, a taxa é a média anual do período.

#' "Incidência" ou, com vários anos, "Incidência média anual".
nome_taxa_mun <- function(anos) if (length(anos) > 1) "Incidência média anual" else "Incidência"

titulo_municipios <- function(m, doenca, uf, anos, por = c("incidencia", "casos")) {
  por <- match.arg(por)
  quantos <- if (nrow(m) > 1) paste0(" Casos em ", formatar_numero(sum(m$casos > 0)), " dos ",
                                     formatar_numero(nrow(m)), " municípios.")
  tagList(
    tags$p(class = "vt-titulo", paste0(if (por == "incidencia") nome_taxa_mun(anos) else "Casos", " de ",
                                       nome_doenca(doenca), " por município ", lugar_titulo(uf), " ", periodo_titulo(anos))),
    tags$p(class = "vt-subtitulo", if (por == "incidencia") {
      paste0("Casos por 100 mil habitantes", if (length(anos) > 1) " por ano", ". ", nome_uf(uf), ": ",
             formatar_numero(attr(m, "taxa_uf"), casas_taxa(m$incidencia)), ".", quantos)
    } else {
      paste0("Pelo município de residência. ", nome_uf(uf), ": ", formatar_numero(attr(m, "casos_uf")), " casos.", quantos)
    })
  )
}

grafico_mapa_mun <- function(m, doenca, uf, anos, por = c("incidencia", "casos")) {
  por <- match.arg(por)
  v <- valor_mapa(m, por)
  cl <- classes_mapa(v$valor, v$casas, m$casos)
  casas_inc <- casas_taxa(m$incidencia)
  rotulo <- paste0(
    "<b>", htmltools::htmlEscape(m$nome), "</b><br/>",
    formatar_numero(m$casos), ifelse(m$casos == 1, " caso", " casos"), "<br/>",
    ifelse(is.na(m$incidencia), "sem população no período",
           paste0(formatar_numero(m$incidencia, casas_inc), " por 100 mil hab.", if (length(anos) > 1) " por ano")),
    "<br/>População: ", ifelse(is.na(m$populacao), "–", formatar_numero(m$populacao)),
    if (length(anos) > 1) " (média)"
  )
  b <- sf::st_bbox(m)
  leaflet(m, options = leafletOptions(zoomSnap = 0.25, attributionControl = FALSE)) |>
    fitBounds(b[["xmin"]], b[["ymin"]], b[["xmax"]], b[["ymax"]]) |>
    addPolygons(
      fillColor = cl$cor, fillOpacity = 1, weight = 0.6, opacity = 1, color = "#FFFFFF",
      highlightOptions = highlightOptions(weight = 2, color = CORES$tinta, bringToFront = TRUE),
      label = lapply(rotulo, htmltools::HTML),
      labelOptions = labelOptions(style = list("font-weight" = "normal", "font-family" = FONTE, padding = "4px 8px"),
                                  textsize = "13px", direction = "auto")
    ) |>
    addLegend(colors = cl$cores, labels = cl$rotulos, opacity = 1, position = "bottomleft",
              title = paste0(if (por == "incidencia") "por 100 mil hab." else "casos",
                             "<br/><span style='font-weight:400'>(quintis dos municípios)</span>"))
}

#' Os `n` municípios com maior valor (só os com casos), com a taxa da UF tracejada.
grafico_ranking_mun <- function(m, doenca, uf, anos, por = c("incidencia", "casos"), n = 20) {
  por <- match.arg(por)
  taxa_uf <- attr(m, "taxa_uf")
  casos_uf <- attr(m, "casos_uf")
  v <- valor_mapa(m, por)
  m$cor <- classes_mapa(v$valor, v$casas, m$casos)$cor
  m$valor <- v$valor
  m <- sf::st_drop_geometry(m)
  total_mun <- nrow(m)
  casas_inc <- casas_taxa(m$incidencia)
  acima <- sum(m$incidencia > taxa_uf, na.rm = TRUE)
  m <- m[m$casos > 0 & !is.na(m$valor), ]
  shiny::validate(shiny::need(nrow(m) > 0, "Nenhum caso no período."))
  m <- utils::head(m[order(-m$valor, m$nome), ], n)
  pontos <- list_parse(data.frame(y = m$valor, color = m$cor, rotulo = formatar_numero(m$valor, v$casas),
                                  casos = paste(formatar_numero(m$casos), ifelse(m$casos == 1, "caso", "casos")),
                                  incid = formatar_numero(m$incidencia, casas_inc), pop = formatar_numero(m$populacao)))
  sigla <- ufs$SIGLA_UF[match(as.integer(uf), ufs$CD_UF)]
  linhas <- list()
  if (por == "incidencia") {
    titulo <- if (total_mun > 1) paste0(formatar_numero(acima), " dos ", formatar_numero(total_mun),
                                        " municípios ficaram acima da taxa da UF") else m$nome[1]
    sub <- paste0(if (nrow(m) > 1) paste("Os", nrow(m), "com maior incidência, por") else "Por",
                  " 100 mil habitantes", if (length(anos) > 1) " por ano", ". Linha tracejada: ", sigla, ".")
    linhas <- list(list(value = taxa_uf, color = CORES$tinta, width = 1.5, dashStyle = "Dash", zIndex = 2,
                        label = list(text = paste(sigla, formatar_numero(taxa_uf, casas_inc)), rotation = 0, align = "left",
                                     verticalAlign = "bottom", x = 4, y = -4,
                                     style = list(color = CORES$tinta, fontWeight = "600", fontSize = "13px"))))
  } else {
    pct <- 100 * m$casos[1] / casos_uf
    titulo <- if (total_mun > 1) paste0(m$nome[1], " teve ", formatar_numero(pct, if (pct < 10) 1 else 0), "% dos casos da UF") else m$nome[1]
    sub <- paste0(if (nrow(m) > 1) paste("Os", nrow(m), "com mais casos, pelo") else "Pelo", " município de residência.")
  }
  highchart() |>
    hc_chart(type = "bar") |>
    hc_add_series(data = pontos, name = if (por == "incidencia") "Incidência" else "Casos",
                  dataLabels = list(enabled = TRUE, format = "{point.rotulo}", crop = FALSE, overflow = "allow",
                                    zIndex = 6, style = list(fontSize = "12px", textOutline = "3px #FFFFFF"))) |>
    hc_plotOptions(bar = list(pointPadding = 0.12, groupPadding = 0, borderWidth = 0)) |>
    hc_xAxis(categories = m$nome, lineColor = CORES$tinta, tickLength = 0, labels = list(step = 1, style = list(fontSize = "12px"))) |>
    hc_yAxis(min = 0, maxPadding = 0.22, gridLineWidth = 0, labels = list(enabled = FALSE), title = list(text = ""),
             plotLines = linhas) |>
    hc_title(text = titulo, style = list(fontSize = "16px")) |>
    hc_subtitle(text = sub, style = list(fontSize = "13px")) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(headerFormat = "<b>{point.key}</b><br/>",
               pointFormat = paste0("{point.casos}<br/>{point.incid} por 100 mil hab.",
                                    if (length(anos) > 1) " por ano", "<br/>População: {point.pop}")) |>
    compacto(list(legend = list(enabled = FALSE)), largura = 380) |>
    exportacao(doenca, "ranking_municipios")
}

# ---- UFs por ano (mapa de calor) --------------------------------------------

#' Mapa de calor UF × ano: todas as UFs e todos os anos de uma vez, na mesma
#' escala (faixas pelos quintis de todas as células com casos, como no mapa).
#' Uma linha por UF, na ordem do IBGE, agrupadas por região (nome à direita).
#' Substitui a corrida de barras animada, que mostrava um ano por vez e mudava
#' a escala a cada ano, sem dar para comparar os anos.
grafico_calor <- function(d, doenca, tipo) {
  incid <- tipo == "Incidência"
  casas <- if (incid) casas_taxa(d$valor) else 0
  anos <- sort(unique(d$ano))
  prelim <- setdiff(anos, anos_finais(doenca))
  uf_ord <- unique(d[order(d$uf), c("uf", "sigla", "regiao")])
  cl <- classes_mapa(d$valor, casas, d$casos)
  rotulo <- if (incid) {
    paste0(formatar_numero(d$valor, casas), " por 100 mil hab. (", formatar_numero(d$casos), " casos)")
  } else {
    paste(formatar_numero(d$casos), "casos")
  }
  pontos <- list_parse(data.frame(
    x = match(d$ano, anos) - 1, y = match(d$uf, uf_ord$uf) - 1, value = d$valor, color = cl$cor,
    nome = ufs$NM_UF[match(d$uf, ufs$CD_UF)], ano = d$ano, rotulo = rotulo
  ))
  # Separação entre as regiões e o nome de cada uma no meio do seu grupo
  fim_regiao <- cumsum(rle(uf_ord$regiao)$lengths)
  meio <- floor((c(0, utils::head(fim_regiao, -1)) + fim_regiao - 1) / 2)
  nomes_regiao <- rep("", nrow(uf_ord))
  nomes_regiao[meio + 1] <- rle(uf_ord$regiao)$values
  separadores <- lapply(utils::head(fim_regiao, -1) - 0.5, function(v) list(value = v, color = "#FFFFFF", width = 4, zIndex = 5))

  hc <- highchart(height = 700) |>
    hc_chart(type = "heatmap", spacingRight = 8, events = list(render = JS("VT.calorSemSalto"))) |>
    hc_add_series(data = pontos, name = if (incid) "Incidência" else "Casos", borderWidth = 1, borderColor = "#FFFFFF",
                  showInLegend = FALSE)
  # Legenda das faixas: séries vazias, só para aparecer na legenda (da menor
  # para a maior; "sem casos" no fim)
  ordem <- rev(seq_along(cl$cores))
  if (cl$rotulos[length(cl$rotulos)] == "Sem casos") ordem <- c(rev(seq_len(length(cl$cores) - 1)), length(cl$cores))
  for (i in ordem) {
    hc <- hc |> hc_add_series(data = list(), type = "scatter", name = cl$rotulos[i], color = cl$cores[i],
                              marker = list(symbol = "square", radius = 6), enableMouseTracking = FALSE)
  }
  hc |>
    hc_title(text = paste0(if (incid) "Incidência" else "Casos", " de ", nome_doenca(doenca), " por UF e ano ", periodo_titulo(anos))) |>
    hc_subtitle(text = paste0(if (incid) "Casos por 100 mil habitantes" else "Casos notificados",
                              ", pela UF de residência. Faixas pelos quintis de todas as UFs e anos com casos: a mesma escala em todos os anos.",
                              if (length(prelim)) " * Dados preliminares." else "")) |>
    hc_xAxis(categories = ifelse(anos %in% prelim, paste0(anos, "*"), anos), lineWidth = 0, tickLength = 0,
             labels = list(autoRotation = FALSE)) |>
    hc_yAxis_multiples(
      list(categories = uf_ord$sigla, reversed = TRUE, title = list(text = ""), gridLineWidth = 0,
           labels = list(step = 1, style = list(fontSize = "12px")), plotLines = separadores),
      list(categories = nomes_regiao, reversed = TRUE, linkedTo = 0, opposite = TRUE, title = list(text = ""),
           gridLineWidth = 0, lineWidth = 0, tickLength = 0,
           labels = list(step = 1, style = list(color = CORES$tinta_suave, fontSize = "12px")))
    ) |>
    hc_legend(enabled = TRUE, symbolRadius = 0, itemDistance = 14,
              title = list(text = if (incid) "por 100 mil hab." else "casos", style = list(fontWeight = "600"))) |>
    hc_tooltip(headerFormat = "", pointFormat = "<b>{point.nome}, {point.ano}</b><br/>{point.rotulo}") |>
    # Celular: anos de 5 em 5 e sem o nome das regiões (falta largura)
    hc_responsive(rules = list(list(condition = list(maxWidth = 520), chartOptions = list(
      title = list(style = list(fontSize = "16px")), subtitle = list(style = list(fontSize = "13px")),
      xAxis = list(labels = list(step = 5, rotation = 0)),
      yAxis = list(list(labels = list(style = list(fontSize = "11px"))), list(labels = list(enabled = FALSE))),
      legend = list(itemDistance = 10, alignColumns = FALSE)
    )))) |>
    exportacao(doenca, "ufs_por_ano")
}

# ---- tendência (joinpoint) -----------------------------------------------

#' Sentido de um segmento: crescente (ruim, vermelho), decrescente (bom, azul)
#' ou estável (tinta). A palavra e o sinal sempre acompanham a cor.
sentido <- function(apc, significativo) {
  ifelse(!significativo, "estavel", ifelse(apc > 0, "cresce", "cai"))
}
COR_SENTIDO <- c(cresce = CORES$negativo, cai = CORES$positivo, estavel = CORES$tinta)
NOME_SENTIDO <- c(cresce = "Crescente", cai = "Decrescente", estavel = "Estável")

#' Título-conclusão a partir do último segmento.
titulo_tendencia <- function(doenca, t) {
  ult <- t[t$tipo == "APC", ]
  ult <- ult[which.max(ult$segmento), ]
  s <- sentido(ult$apc, ult$significativo)
  paste0(nome_doenca(doenca), ": incidência ", switch(
    s,
    cresce = paste0("sobe ", formatar_numero(ult$apc, 1), "% ao ano"),
    cai = paste0("cai ", formatar_numero(abs(ult$apc), 1), "% ao ano"),
    estavel = "estável"
  ), " desde ", ult$ano_inicio)
}

#' `log`: eixo y em escala logarítmica, onde o modelo (reta no log da taxa) aparece como retas.
grafico_tendencia <- function(t, obs, doenca, log = FALSE) {
  aj <- tendencia_ajustada(t)
  seg <- t[t$tipo == "APC", ]
  aapc <- t[t$tipo == "AAPC", ]
  casas <- casas_taxa(obs$incidencia)
  usados <- obs[obs$ano %in% aj$ano, ]
  fora <- obs[!obs$ano %in% aj$ano, ]
  # No log, ano com zero casos fica sem ponto (o log de zero não existe)
  pontos_obs <- function(x) list_parse(data.frame(x = x$ano, y = if (log) ifelse(x$incidencia > 0, x$incidencia, NA) else x$incidencia,
                                                  casos = formatar_numero(x$casos)))
  hc <- highchart() |>
    hc_add_series(data = pontos_obs(usados), type = "scatter", name = "Taxa observada", color = CORES$contexto,
                  lineWidth = 0, marker = list(enabled = TRUE, radius = 5, symbol = "circle"), zIndex = 2,
                  tooltip = list(pointFormat = paste0("<b>{point.x}</b>: {point.y:,.", casas, "f} por 100 mil ({point.casos} casos)")))
  if (nrow(fora) > 0) {
    pf <- pontos_obs(fora)
    pf[[1]]$dataLabels <- list(enabled = TRUE, format = "preliminar", y = -8,
                               style = list(color = CORES$tinta_suave, fontSize = "12px"))
    hc <- hc |> hc_add_series(data = pf, type = "scatter", name = "Preliminar (fora do modelo)", zIndex = 2,
                              color = CORES$contexto, lineWidth = 0,
                              marker = list(enabled = TRUE, radius = 5, symbol = "circle", fillColor = "#FFFFFF", lineWidth = 1.5,
                                            lineColor = CORES$contexto),
                              tooltip = list(pointFormat = paste0("<b>{point.x}</b> (preliminar): {point.y:,.", casas, "f} por 100 mil")))
  }
  for (i in seq_len(nrow(seg))) {
    s <- seg[i, ]
    a <- aj[aj$segmento == s$segmento, ]
    sd <- sentido(s$apc, s$significativo)
    pts <- list_parse(data.frame(x = a$ano, y = a$ajustada))
    if (i > 1) pts[[1]]$marker <- list(enabled = TRUE, radius = 5, fillColor = CORES$tinta, lineWidth = 0)
    # Rótulo à direita do meio do segmento, do lado em que a linha não passa:
    # abaixo quando ela sobe, acima quando ela desce.
    meio <- ceiling(length(pts) / 2)
    sobe <- s$apc > 0
    pts[[meio]]$dataLabels <- list(
      enabled = TRUE, crop = FALSE, overflow = "allow", align = "left", x = 8, className = "vt-rotulo-segmento",
      verticalAlign = if (sobe) "top" else "bottom", y = if (sobe) 8 else -6,
      format = sprintf('<span style="font-weight:600;color:%s">%s%% ao ano</span> <span style="color:%s">%s</span>',
                       COR_SENTIDO[[sd]], com_sinal(s$apc, 1), CORES$tinta_suave, tolower(NOME_SENTIDO[[sd]]))
    )
    hc <- hc |> hc_add_series(
      data = pts, type = "line", name = paste0(s$ano_inicio, "–", s$ano_fim), color = COR_SENTIDO[[sd]],
      lineWidth = 3, zIndex = 3, marker = list(enabled = FALSE),
      tooltip = list(pointFormat = sprintf("Segmento {series.name}: <b>%s%% ao ano</b> (IC 95%%: %s a %s), %s",
                                           com_sinal(s$apc, 1), com_sinal(s$apc_ic_inf, 1), com_sinal(s$apc_ic_sup, 1),
                                           tolower(NOME_SENTIDO[[sd]])))
    )
  }
  anos <- range(aj$ano)
  hc |>
    hc_title(text = titulo_tendencia(doenca, t)) |>
    hc_subtitle(text = paste0(
      "Casos por 100 mil habitantes, Brasil, ", periodo_anos(anos), ". Pontos: taxa observada; linha: tendência ajustada (joinpoint).",
      if (nrow(aapc)) paste0(" Variação média do período (AAPC): ", com_sinal(aapc$apc[1], 1), "% ao ano.") else ""
    )) |>
    hc_xAxis(allowDecimals = FALSE, tickInterval = if (diff(range(obs$ano)) > 12) 2 else 1) |>
    hc_yAxis(type = if (log) "logarithmic" else "linear", min = if (!log) 0,
             title = list(text = if (log) "por 100 mil hab. (escala log)" else "por 100 mil hab."),
             plotLines = if (log) list() else linha_base()) |>
    hc_legend(enabled = FALSE) |>
    hc_tooltip(headerFormat = "") |>
    # No celular, o APC de cada segmento fica só na tabela abaixo (o rótulo
    # some pelo CSS, classe vt-rotulo-segmento)
    compacto(list(legend = list(enabled = FALSE), xAxis = list(tickInterval = 5))) |>
    exportacao(doenca, "tendencia")
}

#' Tabela que se lê (receita 17): APC por segmento e AAPC do período.
tabela_tendencia <- function(t) {
  linhas <- lapply(seq_len(nrow(t)), function(i) {
    x <- t[i, ]
    sd <- sentido(x$apc, x$significativo)
    total <- x$tipo == "AAPC"
    tags$tr(class = if (total) "vt-total",
            tags$td(if (total) paste0("Período todo (AAPC) ", x$ano_inicio, "–", x$ano_fim) else paste0(x$ano_inicio, "–", x$ano_fim)),
            tags$td(class = "num", com_sinal(x$apc, 1)),
            tags$td(class = "num", paste0(com_sinal(x$apc_ic_inf, 1), " a ", com_sinal(x$apc_ic_sup, 1))),
            tags$td(tags$span(class = paste("vt-sentido", sd), NOME_SENTIDO[[sd]])))
  })
  tags$table(class = "vt-tabela",
             tags$thead(tags$tr(tags$th("Período"),
                                tags$th(class = "num", "APC", tags$small("% ao ano")),
                                tags$th(class = "num", "IC 95%", tags$small("% ao ano")),
                                tags$th("Tendência"))),
             tags$tbody(linhas))
}
