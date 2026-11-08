# Aba Tendência: regressão segmentada (joinpoint) recalculada pelo pipeline a
# cada atualização dos dados (data/gold/tendencia.parquet). A tabela estática
# do TCC (Joinpoint/NCI, dados de 2024) fica recolhida, como referência.

tendencia <- layout_sidebar(
  sidebar = sidebar(
    pickerInput("doenca_tend", "Selecione a doença de interesse", choices = escolhas_doenca),
    width = 280
  ),
  card(
    full_screen = TRUE,
    card_header("Tendência da incidência no Brasil"),
    highchartOutput("tend_plot", height = "420px"),
    uiOutput("tend_tabela"),
    card_footer(uiOutput("nota_tend"))
  ),
  card(
    card_header("Método"),
    tags$div(
      style = "line-height: 1.6;",
      tags$p(
        "A tendência da incidência anual (por 100 mil habitantes, Brasil) é estimada por regressão",
        "segmentada (joinpoint) sobre o logaritmo da taxa: a série é dividida em até quatro segmentos",
        "lineares na escala log, separados por pontos de inflexão em anos inteiros (no mínimo dois anos",
        "entre eles e nas pontas). O número de pontos de inflexão (0 a 3) é escolhido pelo critério BIC,",
        "como no Joinpoint Regression Software do US National Cancer Institute."
      ),
      tags$p(
        "A variação percentual anual (APC) de cada segmento é 100·(e", tags$sup("b"), " − 1), com",
        "intervalo de 95% pela t de Student. A variação percentual anual média (AAPC) resume o período:",
        "é a média dos coeficientes dos segmentos, ponderada pelo número de anos. A tendência é",
        "considerada crescente ou decrescente quando o IC 95% não contém o zero; caso contrário, estável."
      ),
      tags$p(
        "Entram só os anos com dados finais (os preliminares ainda mudam). O cálculo é refeito a cada",
        "atualização dos dados, então pode diferir do TCC (2024), que usou o Joinpoint com teste de",
        "permutação, intervalo empírico e os dados disponíveis em 2024."
      ),
      tags$details(
        tags$summary("Resultado publicado no TCC (Joinpoint 5.2.0, dados coletados em 2024)"),
        tags$div(style = "text-align: center; margin-top: 12px;",
                 tags$img(src = "tabbordas.png", alt = "Tabela de tendência do TCC", style = "max-width: 100%; height: auto;"))
      )
    )
  )
)
