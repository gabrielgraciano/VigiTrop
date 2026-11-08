# Dados do app: lidos UMA vez, na inicialização, do gold gerado pelo pipeline
# (data/gold, ver pipeline/README.md). Sem MySQL e sem SQL montado com texto
# vindo da interface: os filtros são feitos em memória, com valores validados.
#
# Regras do gold:
#   - não existe linha "Brasil" nem faixa "Todos": o total é sempre a soma
#     (eram essas linhas agregadas que dobravam as contagens no app antigo);
#   - uf = código IBGE da UF de residência; NA = ignorada;
#   - sexo M/F/I; faixa_etaria '0-4' ... '90 ou mais' e 'Ignorado';
#   - ano = ano de notificação.

dir_gold <- Sys.getenv("VIGITROP_GOLD", file.path("..", "data", "gold"))

ler_parquet <- function(arquivo) {
  caminho <- normalizePath(file.path(dir_gold, arquivo), mustWork = TRUE)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, paste0("SELECT * FROM read_parquet(", DBI::dbQuoteString(con, caminho), ")"))
}

FAIXAS <- c("0-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39", "40-44",
            "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80-84", "85-89",
            "90 ou mais")
SEXOS <- c("Ambos" = "Ambos", "Masculino" = "M", "Feminino" = "F")
RACAS <- c("1" = "Branca", "2" = "Preta", "3" = "Amarela", "4" = "Parda", "5" = "Indígena", "9" = "Ignorada")
BRASIL <- "BR"

# ---- leitura -----------------------------------------------------------------

definicoes <- ler_parquet("doencas.parquet")
padroes <- definicoes[definicoes$padrao, c("doenca", "codigo", "nome", "definicao", "texto_app")]

# Só a contagem padrão de cada doença (ver pipeline/config/doencas.yaml)
casos <- merge(ler_parquet("casos.parquet"), padroes[, c("doenca", "definicao")], by = c("doenca", "definicao"))
casos$definicao <- NULL
casos$uf <- as.integer(casos$uf)
casos$ano <- as.integer(casos$ano)

# Casos por mês de notificação (os 12 meses somam o ano de `casos`)
casos_mes <- merge(ler_parquet("casos_mes.parquet"), padroes[, c("doenca", "definicao")], by = c("doenca", "definicao"))
casos_mes$definicao <- NULL
casos_mes$uf <- as.integer(casos_mes$uf)
casos_mes$mes <- as.Date(casos_mes$mes)

# Casos por semana epidemiológica de início dos sintomas (sem hanseníase e LTA)
casos_semana <- merge(ler_parquet("casos_semana.parquet"), padroes[, c("doenca", "definicao")], by = c("doenca", "definicao"))
casos_semana$definicao <- NULL
casos_semana$uf <- as.integer(casos_semana$uf)
casos_semana$inicio_semana <- as.Date(casos_semana$inicio_semana)

populacao <- ler_parquet("populacao.parquet")
populacao$uf <- as.integer(populacao$uf)
populacao$ano <- as.integer(populacao$ano)

arquivos <- ler_parquet("arquivos.parquet")
arquivos$ano <- as.integer(arquivos$ano)
meta <- jsonlite::fromJSON(file.path(dir_gold, "meta.json"))

ufs_sf <- sf::st_read(file.path("mapas", "uf_2022.geojson"), quiet = TRUE)
ufs_sf$CD_UF <- as.integer(ufs_sf$CD_UF)
ufs <- sf::st_drop_geometry(ufs_sf)
ufs <- ufs[order(ufs$NM_UF), ]

# ---- escolhas da interface (derivadas dos dados, nada fixo no código) --------

escolhas_doenca <- stats::setNames(padroes$doenca, padroes$nome)
escolhas_doenca <- escolhas_doenca[order(names(escolhas_doenca))]
escolhas_doenca_semana <- escolhas_doenca[escolhas_doenca %in% unique(casos_semana$doenca)]
escolhas_uf <- stats::setNames(as.character(ufs$CD_UF), ufs$NM_UF)
escolhas_uf_brasil <- c("Brasil" = BRASIL, escolhas_uf)
anos_disponiveis <- sort(unique(arquivos$ano))
ano_padrao <- max(arquivos$ano[arquivos$status == "FINAL"])

nome_uf <- function(uf) if (identical(uf, BRASIL)) "Brasil" else ufs$NM_UF[match(as.integer(uf), ufs$CD_UF)]
nome_doenca <- function(d) padroes$nome[match(d, padroes$doenca)]
rotulo_sexo <- function(s) names(SEXOS)[match(s, SEXOS)]

# Valida o que vem da interface (inputs de Shiny podem ser forjados no navegador)
validar <- function(valor, permitidos) {
  shiny::req(length(valor) > 0, all(valor %in% permitidos))
  valor
}

anos_da_doenca <- function(doenca) sort(arquivos$ano[arquivos$doenca == doenca])

filtrar_uf <- function(df, uf) {
  if (identical(uf, BRASIL)) df else df[!is.na(df$uf) & df$uf == as.integer(uf), , drop = FALSE]
}

somar_por_ano <- function(valores, anos_obs, anos) {
  s <- tapply(valores, factor(anos_obs, levels = anos), sum)
  s[is.na(s)] <- 0
  as.numeric(s)
}

# ---- cálculos ----------------------------------------------------------------

#' Incidência por 100 mil, anual ou mensal. `uf` = código IBGE ou "BR"; `sexo`
#' = M, F ou "Ambos"; `faixas` = vetor de faixas ou "Todos". Brasil inclui casos
#' com UF ignorada; "Ambos" inclui sexo ignorado; "Todos" inclui idade ignorada.
#' Mensal: casos notificados no mês por 100 mil habitantes (população do ano).
serie_incidencia <- function(doenca, uf, sexo, faixas, periodicidade = c("anual", "mensal")) {
  periodicidade <- match.arg(periodicidade)
  anos <- anos_da_doenca(doenca)
  base <- if (periodicidade == "anual") casos else casos_mes
  cs <- filtrar_uf(base[base$doenca == doenca, ], uf)
  ps <- filtrar_uf(populacao[populacao$ano %in% anos, ], uf)
  if (sexo != "Ambos") {
    cs <- cs[cs$sexo == sexo, ]
    ps <- ps[ps$sexo == sexo, ]
  }
  if (!"Todos" %in% faixas) {
    cs <- cs[cs$faixa_etaria %in% faixas, ]
    ps <- ps[ps$faixa_etaria %in% faixas, ]
  }
  p <- somar_por_ano(ps$populacao, ps$ano, anos)
  if (periodicidade == "anual") {
    n <- somar_por_ano(cs$casos, cs$ano, anos)
    return(data.frame(ano = anos, casos = n, populacao = p, incidencia = round(n / p * 1e5, 2)))
  }
  ultimo <- max(casos_mes$mes[casos_mes$doenca == doenca])
  meses <- seq(as.Date(sprintf("%d-01-01", min(anos))), ultimo, by = "month")
  n <- tapply(cs$casos, factor(as.character(cs$mes), levels = as.character(meses)), sum)
  n[is.na(n)] <- 0
  pop_mes <- p[match(as.integer(format(meses, "%Y")), anos)]
  data.frame(mes = meses, casos = as.numeric(n), populacao = pop_mes, incidencia = round(as.numeric(n) / pop_mes * 1e5, 3))
}

#' Casos e incidência por UF num ano (para o mapa). Casos com UF ignorada ficam
#' de fora do mapa; a quantidade volta em attr(, "sem_uf").
dados_mapa <- function(doenca, ano) {
  sel <- casos[casos$doenca == doenca & casos$ano == ano, ]
  n_uf <- tapply(sel$casos[!is.na(sel$uf)], sel$uf[!is.na(sel$uf)], sum)
  pop <- populacao[populacao$ano == ano, ]
  p_uf <- tapply(pop$populacao, pop$uf, sum)
  m <- ufs_sf
  m$casos <- as.numeric(n_uf[as.character(m$CD_UF)])
  m$casos[is.na(m$casos)] <- 0
  m$populacao <- as.numeric(p_uf[as.character(m$CD_UF)])
  m$incidencia <- round(m$casos / m$populacao * 1e5, 2)
  attr(m, "sem_uf") <- sum(sel$casos[is.na(sel$uf)])
  m
}

#' Casos por ano numa UF, distribuídos por sexo (M/F; sexo ignorado fica de
#' fora) ou por raça/cor (1-5 e 9 = ignorada, que entra na conta), com a
#' porcentagem de cada grupo no ano.
dados_barras <- function(doenca, uf, por = c("sexo", "raca")) {
  por <- match.arg(por)
  grupos <- if (por == "sexo") c("M", "F") else names(RACAS)
  cs <- filtrar_uf(casos[casos$doenca == doenca & casos[[por]] %in% grupos, ], uf)
  anos <- anos_da_doenca(doenca)
  out <- expand.grid(ano = anos, grupo = grupos, stringsAsFactors = FALSE)
  s <- tapply(cs$casos, paste(cs$ano, cs[[por]]), sum)
  out$casos <- as.numeric(s[paste(out$ano, out$grupo)])
  out$casos[is.na(out$casos)] <- 0
  tot <- ave(out$casos, out$ano, FUN = sum)
  out$porcentagem <- ifelse(tot > 0, 100 * out$casos / tot, NA_real_)
  out
}

#' Casos por semana epidemiológica de início dos sintomas, por UF (ou Brasil),
#' entre os anos `de` e `ate`. Semanas sem caso entram com zero.
dados_semana <- function(doenca, ufs_sel, de, ate) {
  sel <- casos_semana[casos_semana$doenca == doenca & casos_semana$semana %/% 100 >= de & casos_semana$semana %/% 100 <= ate, ]
  semanas <- sort(unique(casos_semana$inicio_semana[casos_semana$semana %/% 100 >= de & casos_semana$semana %/% 100 <= ate]))
  saida <- lapply(ufs_sel, function(u) {
    d <- filtrar_uf(sel, u)
    n <- tapply(d$casos, factor(as.character(d$inicio_semana), levels = as.character(semanas)), sum)
    n[is.na(n)] <- 0
    data.frame(inicio_semana = semanas, casos = as.numeric(n), uf = nome_uf(u))
  })
  do.call(rbind, saida)
}

#' Casos por faixa etária e sexo (M/F) numa UF e ano. Idade ignorada volta em attr(, "sem_idade").
dados_piramide <- function(doenca, uf, ano) {
  cs <- filtrar_uf(casos[casos$doenca == doenca & casos$ano == ano & casos$sexo %in% c("M", "F"), ], uf)
  out <- expand.grid(faixa_etaria = FAIXAS, sexo = c("M", "F"), stringsAsFactors = FALSE)
  s <- tapply(cs$casos, paste(cs$faixa_etaria, cs$sexo), sum)
  out$casos <- as.numeric(s[paste(out$faixa_etaria, out$sexo)])
  out$casos[is.na(out$casos)] <- 0
  attr(out, "sem_idade") <- sum(cs$casos[cs$faixa_etaria == "Ignorado"])
  out
}

#' Valor por UF e ano, com a posição no ranking do ano (para a animação).
dados_corrida <- function(doenca, tipo) {
  anos <- anos_da_doenca(doenca)
  sel <- casos[casos$doenca == doenca & !is.na(casos$uf), ]
  grade <- expand.grid(ano = anos, uf = ufs$CD_UF)
  s <- tapply(sel$casos, paste(sel$ano, sel$uf), sum)
  grade$casos <- as.numeric(s[paste(grade$ano, grade$uf)])
  grade$casos[is.na(grade$casos)] <- 0
  p <- tapply(populacao$populacao, paste(populacao$ano, populacao$uf), sum)
  grade$populacao <- as.numeric(p[paste(grade$ano, grade$uf)])
  grade$valor <- if (tipo == "Incidência") round(grade$casos / grade$populacao * 1e5, 2) else grade$casos
  grade$sigla <- ufs$SIGLA_UF[match(grade$uf, ufs$CD_UF)]
  grade$regiao <- c("1" = "Norte", "2" = "Nordeste", "3" = "Sudeste", "4" = "Sul", "5" = "Centro-Oeste")[as.character(grade$uf %/% 10)]
  grade <- grade[order(grade$ano, -grade$valor, grade$sigla), ]
  grade$posicao <- ave(grade$valor, grade$ano, FUN = seq_along)
  grade
}

# ---- textos ------------------------------------------------------------------

faixas_de_anos <- function(anos) {
  anos <- sort(unique(anos))
  if (!length(anos)) return("")
  grupos <- split(anos, cumsum(c(1, diff(anos) != 1)))
  paste(vapply(grupos, function(g) if (length(g) > 1) paste0(g[1], "–", g[length(g)]) else as.character(g), ""), collapse = ", ")
}

formatar_numero <- function(x, digitos = 0) {
  formatC(x, format = "f", digits = digitos, big.mark = ".", decimal.mark = ",")
}

#' Nota de rodapé: definição de caso, ressalvas, fonte, data de coleta e anos preliminares.
nota_doenca <- function(doenca, extra = NULL) {
  a <- arquivos[arquivos$doenca == doenca, ]
  prelim <- a$ano[a$status == "PRELIM"]
  coleta <- format(as.Date(substr(max(a$data_coleta), 1, 10)), "%d/%m/%Y")
  shiny::tags$small(
    class = "text-muted",
    shiny::tags$p(shiny::tags$b(paste0(nome_doenca(doenca), ": ")), padroes$texto_app[padroes$doenca == doenca]),
    if (length(extra)) shiny::tags$p(extra),
    shiny::tags$p(paste0(
      "Fonte: SINAN/DataSUS (via PySUS), coleta em ", coleta, ". ",
      "População: projeção IBGE, revisão 2024. Ano de notificação; UF de residência.",
      if (length(prelim)) paste0(" Dados preliminares (sujeitos a revisão): ", faixas_de_anos(prelim), ".")
    ))
  )
}
