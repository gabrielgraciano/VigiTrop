# Dados do app: lidos UMA vez, na inicialização, do gold gerado pelo pipeline
# (data/gold, ver pipeline/README.md). Sem MySQL. Os filtros são feitos em
# memória, com valores validados; só as séries mensal e semanal, grandes demais
# para a memória, são consultadas na hora pelo DuckDB, com SQL fixo e os valores
# da interface (já validados) passados como parâmetros, nunca colados no texto.
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

# Séries mensal (mês de notificação) e semanal (semana de início dos sintomas;
# sem hanseníase e LTA): com sexo, faixa e raça/cor, têm milhões de linhas, então
# ficam no disco e o DuckDB consulta na hora (ver dados_serie). A conexão é do
# processo R e dura enquanto ele vive.
con_gold <- DBI::dbConnect(duckdb::duckdb())
for (tabela in c("casos", "casos_mes", "casos_semana")) {
  caminho <- normalizePath(file.path(dir_gold, paste0(tabela, ".parquet")), mustWork = TRUE)
  DBI::dbExecute(con_gold, paste0("CREATE VIEW g_", tabela, " AS SELECT * FROM read_parquet(",
                                  DBI::dbQuoteString(con_gold, caminho), ")"))
}
# Gold de antes da aba única não tem raça/cor (nem sexo e faixa na semanal): a aba avisa
colunas <- function(tabela) DBI::dbGetQuery(con_gold, paste0("DESCRIBE g_", tabela))$column_name
tem_series_completas <- "raca" %in% colunas("casos_mes") && all(c("sexo", "faixa_etaria", "raca") %in% colunas("casos_semana"))
# Calendário das semanas epidemiológicas e último mês/semana com dados de cada doença
semanas <- DBI::dbGetQuery(con_gold, "SELECT DISTINCT semana, inicio_semana FROM g_casos_semana ORDER BY semana")
semanas$inicio_semana <- as.Date(semanas$inicio_semana)
ultimos <- DBI::dbGetQuery(con_gold, "
  SELECT m.doenca, m.ultimo_mes, s.ultima_semana
  FROM (SELECT doenca, max(mes) AS ultimo_mes FROM g_casos_mes GROUP BY 1) m
  LEFT JOIN (SELECT doenca, max(semana) AS ultima_semana FROM g_casos_semana GROUP BY 1) s USING (doenca)")
ultimos$ultimo_mes <- as.Date(ultimos$ultimo_mes)

populacao <- ler_parquet("populacao.parquet")
populacao$uf <- as.integer(populacao$uf)
populacao$ano <- as.integer(populacao$ano)

# Tendência (joinpoint) da definição padrão; opcional: sem o arquivo, a aba avisa.
tendencias <- if (file.exists(file.path(dir_gold, "tendencia.parquet"))) ler_parquet("tendencia.parquet") else NULL

arquivos <- ler_parquet("arquivos.parquet")
arquivos$ano <- as.integer(arquivos$ano)
meta <- jsonlite::fromJSON(file.path(dir_gold, "meta.json"))

# Casos e população por município (aba "Municípios"); opcional: sem os
# arquivos (gold de antes da aba), a aba avisa.
tem_municipios <- all(file.exists(file.path(dir_gold, c("casos_municipio.parquet", "populacao_municipio.parquet"))))
if (tem_municipios) {
  casos_mun <- merge(ler_parquet("casos_municipio.parquet"), padroes[, c("doenca", "definicao")], by = c("doenca", "definicao"))
  casos_mun$definicao <- NULL
  casos_mun$uf <- as.integer(casos_mun$uf)
  casos_mun$ano <- as.integer(casos_mun$ano)
  pop_mun <- ler_parquet("populacao_municipio.parquet")
  pop_mun$uf <- as.integer(pop_mun$uf)
  pop_mun$ano <- as.integer(pop_mun$ano)
}

ufs_sf <- sf::st_read(file.path("mapas", "uf_2022.geojson"), quiet = TRUE)
ufs_sf$CD_UF <- as.integer(ufs_sf$CD_UF)
ufs <- sf::st_drop_geometry(ufs_sf)
ufs <- ufs[order(ufs$NM_UF), ]

# ---- escolhas da interface (derivadas dos dados, nada fixo no código) --------

escolhas_doenca <- stats::setNames(padroes$doenca, padroes$nome)
escolhas_doenca <- escolhas_doenca[order(names(escolhas_doenca))]
doencas_com_semana <- ultimos$doenca[!is.na(ultimos$ultima_semana)]
escolhas_uf <- stats::setNames(as.character(ufs$CD_UF), ufs$NM_UF)
escolhas_uf_brasil <- c("Brasil" = BRASIL, escolhas_uf)
# Raiva: tão poucos casos que a incidência por município não diz nada; a aba
# "Municípios" mostra só os casos.
DOENCAS_SO_CASOS <- intersect("raiva_humana", escolhas_doenca)
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
# As taxas saem sem arredondar: o arredondamento é só na exibição (graficos.R),
# senão 1 caso de raiva numa UF grande vira 0,00 e some do mapa.

#' Incidência anual por 100 mil (Brasil ou uma UF), usada na tendência e no mapa.
#' `uf` = código IBGE ou "BR"; `sexo` = M, F ou "Ambos"; `faixas` = vetor de
#' faixas ou "Todos". Brasil inclui casos com UF ignorada; "Ambos" inclui sexo
#' ignorado; "Todos" inclui idade ignorada.
serie_incidencia <- function(doenca, uf, sexo, faixas) {
  anos <- anos_da_doenca(doenca)
  cs <- filtrar_uf(casos[casos$doenca == doenca, ], uf)
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
  n <- somar_por_ano(cs$casos, cs$ano, anos)
  data.frame(ano = anos, casos = n, populacao = p, incidencia = n / p * 1e5)
}

PERIODICIDADES <- c("Anual" = "anual", "Mensal" = "mensal", "Semanal" = "semanal")

#' Uma linha da aba "Série temporal": casos e incidência de uma UF (ou Brasil) e
#' um sexo (ou "Ambos"), somando as `faixas` e as `racas` escolhidas, entre os
#' anos `de` e `ate`, na periodicidade pedida. Períodos sem caso entram com zero.
#'   anual: ano de notificação; mensal: mês de notificação; semanal: semana
#'   epidemiológica de início dos sintomas. A incidência usa a população do ano
#'   (do ano da semana, na semanal). Com raça/cor filtrada, a incidência fica NA:
#'   a projeção do IBGE não tem essa abertura.
#' A consulta tem texto fixo; o que vem da interface entra como parâmetro (?).
dados_serie <- function(doenca, periodicidade, uf, sexo, faixas, racas, de, ate) {
  definicao <- padroes$definicao[padroes$doenca == doenca]
  tempo <- c(anual = "ano", mensal = "mes", semanal = "semana")[[periodicidade]]
  ano_de <- c(anual = "ano", mensal = "year(mes)", semanal = "semana // 100")[[periodicidade]]
  onde <- c("doenca = ?", "definicao = ?", paste(ano_de, "BETWEEN ? AND ?"))
  par <- list(doenca, definicao, as.integer(de), as.integer(ate))
  em <- function(coluna, valores) {
    onde <<- c(onde, paste0(coluna, " IN (", paste(rep("?", length(valores)), collapse = ", "), ")"))
    par <<- c(par, as.list(valores))
  }
  if (!identical(uf, BRASIL)) em("uf", as.integer(uf))
  if (sexo != "Ambos") em("sexo", sexo)
  if (!"Todos" %in% faixas) em("faixa_etaria", faixas)
  if (!"Todas" %in% racas) em("raca", racas)
  sql <- paste0("SELECT ", tempo, " AS t, sum(casos) AS casos FROM g_",
                c(anual = "casos", mensal = "casos_mes", semanal = "casos_semana")[[periodicidade]],
                " WHERE ", paste(onde, collapse = " AND "), " GROUP BY 1")
  r <- DBI::dbGetQuery(con_gold, sql, params = unname(par))

  # Grade completa de períodos: anos com arquivo, meses ou semanas até o último dado da doença
  u <- ultimos[ultimos$doenca == doenca, ]
  if (periodicidade == "anual") {
    t <- anos_da_doenca(doenca)
    t <- t[t >= de & t <= ate]
    ano_t <- t
  } else if (periodicidade == "mensal") {
    inicio <- as.Date(sprintf("%d-01-01", de))
    fim <- min(as.Date(sprintf("%d-12-01", ate)), u$ultimo_mes)
    t <- if (inicio <= fim) seq(inicio, fim, by = "month") else as.Date(character())
    ano_t <- as.integer(format(t, "%Y"))
    r$t <- as.Date(r$t)
  } else {
    sem <- semanas[semanas$semana %/% 100 >= de & semanas$semana %/% 100 <= ate & semanas$semana <= u$ultima_semana, ]
    t <- sem$semana
    ano_t <- t %/% 100
  }
  n <- as.numeric(r$casos[match(as.character(t), as.character(r$t))])
  n[is.na(n)] <- 0

  # População do ano de cada período (mesmos recortes, menos raça/cor)
  ps <- filtrar_uf(populacao[populacao$ano %in% unique(ano_t), ], uf)
  if (sexo != "Ambos") ps <- ps[ps$sexo == sexo, ]
  if (!"Todos" %in% faixas) ps <- ps[ps$faixa_etaria %in% faixas, ]
  p <- tapply(ps$populacao, ps$ano, sum)[as.character(ano_t)]
  out <- data.frame(t = t, casos = n, populacao = as.numeric(p))
  if (periodicidade == "semanal") out$inicio_semana <- sem$inicio_semana
  out$incidencia <- if ("Todas" %in% racas) out$casos / out$populacao * 1e5 else NA_real_
  out
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
  m$incidencia <- m$casos / m$populacao * 1e5
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

#' Casos e incidência (taxa específica por idade e sexo, por 100 mil) por faixa
#' etária e sexo (M/F) numa UF e ano. Idade ignorada volta em attr(, "sem_idade").
dados_piramide <- function(doenca, uf, ano) {
  cs <- filtrar_uf(casos[casos$doenca == doenca & casos$ano == ano & casos$sexo %in% c("M", "F"), ], uf)
  out <- expand.grid(faixa_etaria = FAIXAS, sexo = c("M", "F"), stringsAsFactors = FALSE)
  s <- tapply(cs$casos, paste(cs$faixa_etaria, cs$sexo), sum)
  out$casos <- as.numeric(s[paste(out$faixa_etaria, out$sexo)])
  out$casos[is.na(out$casos)] <- 0
  ps <- filtrar_uf(populacao[populacao$ano == ano, ], uf)
  p <- tapply(ps$populacao, paste(ps$faixa_etaria, ps$sexo), sum)
  out$populacao <- as.numeric(p[paste(out$faixa_etaria, out$sexo)])
  out$incidencia <- out$casos / out$populacao * 1e5
  attr(out, "sem_idade") <- sum(cs$casos[cs$faixa_etaria == "Ignorado"])
  out
}

#' Valor (incidência ou casos) por UF e ano, para a aba "UFs por ano".
dados_uf_ano <- function(doenca, tipo) {
  anos <- anos_da_doenca(doenca)
  sel <- casos[casos$doenca == doenca & !is.na(casos$uf), ]
  grade <- expand.grid(ano = anos, uf = ufs$CD_UF)
  s <- tapply(sel$casos, paste(sel$ano, sel$uf), sum)
  grade$casos <- as.numeric(s[paste(grade$ano, grade$uf)])
  grade$casos[is.na(grade$casos)] <- 0
  p <- tapply(populacao$populacao, paste(populacao$ano, populacao$uf), sum)
  grade$populacao <- as.numeric(p[paste(grade$ano, grade$uf)])
  grade$valor <- if (tipo == "Incidência") grade$casos / grade$populacao * 1e5 else grade$casos
  grade$sigla <- ufs$SIGLA_UF[match(grade$uf, ufs$CD_UF)]
  grade$regiao <- c("1" = "Norte", "2" = "Nordeste", "3" = "Sudeste", "4" = "Sul", "5" = "Centro-Oeste")[as.character(grade$uf %/% 10)]
  grade
}

# Malha dos municípios de cada UF (mapas/municipios/<UF>.geojson), lida na
# primeira vez que a UF é escolhida e guardada.
malhas_municipios <- new.env()
malha_municipios <- function(uf) {
  sigla <- ufs$SIGLA_UF[match(as.integer(uf), ufs$CD_UF)]
  if (is.null(malhas_municipios[[sigla]])) {
    m <- sf::st_read(file.path("mapas", "municipios", paste0(sigla, ".geojson")), quiet = TRUE)
    m$municipio <- as.character(m$municipio)
    malhas_municipios[[sigla]] <- m
  }
  malhas_municipios[[sigla]]
}

# Campo "Município" da aba: os municípios da UF em ordem alfabética (sem
# contar acentos), com "Nenhum" primeiro.
SEM_MUNICIPIO <- "nenhum"
escolhas_municipio <- function(uf) {
  m <- sf::st_drop_geometry(malha_municipios(uf))
  m <- m[order(iconv(m$nome, "UTF-8", "ASCII//TRANSLIT"), m$nome), ]
  c("Nenhum" = SEM_MUNICIPIO, stats::setNames(m$municipio, m$nome))
}

#' Casos e incidência por município de uma UF, somando os anos `anos`. A
#' incidência do período é a média anual: casos / soma das populações dos anos
#' (pessoas-ano) × 100 mil. Casos sem município identificado ficam fora do
#' mapa; a quantidade volta em attr(, "sem_municipio"), e a taxa da UF no
#' período, em attr(, "taxa_uf").
dados_municipios <- function(doenca, uf, anos) {
  uf <- as.integer(uf)
  m <- malha_municipios(uf)
  sel <- casos_mun[casos_mun$doenca == doenca & casos_mun$uf == uf & casos_mun$ano %in% anos, ]
  n <- tapply(sel$casos, sel$municipio, sum)
  p <- pop_mun[pop_mun$uf == uf & pop_mun$ano %in% anos, ]
  pessoas_ano <- tapply(p$populacao, p$municipio, sum)
  anos_pop <- tapply(p$ano, p$municipio, length)
  m$casos <- as.numeric(n[m$municipio])
  m$casos[is.na(m$casos)] <- 0
  m$populacao <- as.numeric(pessoas_ano[m$municipio] / anos_pop[m$municipio])
  m$incidencia <- m$casos / as.numeric(pessoas_ano[m$municipio]) * 1e5
  total <- sum(casos$casos[casos$doenca == doenca & !is.na(casos$uf) & casos$uf == uf & casos$ano %in% anos])
  pop_uf <- sum(populacao$populacao[populacao$uf == uf & populacao$ano %in% anos])
  attr(m, "sem_municipio") <- total - sum(m$casos)
  attr(m, "casos_uf") <- total
  attr(m, "taxa_uf") <- total / pop_uf * 1e5
  m
}

#' Segmentos (APC) e período (AAPC) da tendência de uma doença; NULL se não houver.
tendencia_doenca <- function(doenca) {
  if (is.null(tendencias)) return(NULL)
  t <- tendencias[tendencias$doenca == doenca, ]
  if (!nrow(t)) return(NULL)
  t[order(t$tipo != "APC", t$segmento), ]
}

#' Incidência ajustada pelo modelo, ano a ano, a partir dos segmentos
#' (log-linear: taxa_inicio · (1 + APC/100)^(t − ano_inicio)).
tendencia_ajustada <- function(t) {
  seg <- t[t$tipo == "APC", ]
  do.call(rbind, lapply(seq_len(nrow(seg)), function(i) {
    anos <- seq(seg$ano_inicio[i], seg$ano_fim[i])
    data.frame(ano = anos, segmento = seg$segmento[i],
               ajustada = seg$taxa_inicio[i] * (1 + seg$apc[i] / 100)^(anos - seg$ano_inicio[i]))
  }))
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
    if (length(extra)) shiny::tags$p(if (is.character(extra)) paste(extra, collapse = " ") else extra),
    shiny::tags$p(paste0(
      "Fonte: SINAN/DataSUS (via PySUS), coleta em ", coleta, ". ",
      "População: projeção IBGE, revisão 2024. Ano de notificação; UF de residência.",
      if (length(prelim)) paste0(" Dados preliminares (sujeitos a revisão): ", faixas_de_anos(prelim), ".")
    ))
  )
}
