tendencia <- HTML('
<div style="font-family: Arial, sans-serif; font-size: 16px; line-height: 1.6; color: #333;">
  <h2 style="color: #0072B2;">Tendência</h2>
  <div>
    <p>
      A tendência das séries históricas das taxas de incidência (por 100 mil habitantes) das
      DTNs no Brasil nas últimas décadas foram analisadas por meio do 
      <a href="https://surveillance.cancer.gov/joinpoint/" target="_blank">Joinpoint
      Regression Software version 5.2.0</a> 
      fornecido pelo US National Cancer Institute (NCI). A regressão joinpoint pode
      ser utilizada quando se deseja avaliar a tendência temporal de uma determinada quantidade,
      como incidência, prevalência e mortalidade; buscando identificar pontos de mudança significativos
      na tendência. A variável independente foi o tempo (ano). Para ajuste dos modelos, 
      assumiu-se variância dos erros constante e autocorrelação de primeira ordem estimada 
      a partir dos dados.
    </p>
    <p>
      A variação percentual anual (APC, sigla em inglês para annual percent change) 
      foi calculada, buscando os pontos de inflexão que indicam as variações das taxas
      com maior significância no aumento da linha a ser identificada. 
      O número de pontos necessários para o ajuste de cada segmento foi selecionado 
      automaticamente pela configuração padrão do software. A tendência foi considerada 
      presente quando o zero não esteve contido nos intervalos de 95% de confiança (IC 95%). 
      Sendo ‘ascendente’ quando APC positivo e ‘decrescente’ quando APC negativo.
    </p>
    <p>
      Também foi calculada a variação percentual anual média (AAPC, sigla em inglês 
      para average annual percentage change), que é uma medida que resume a tendência
      de período, descrevendo a média do APC. 
      Nas variáveis em que apenas um APC abrange todo o período estudado, o AAPC é igual 
      ao APC.
    </p>
    <div style="text-align: center; margin-top: 20px;">
      <img src="tabbordas.png" alt="Tabela com bordas" style="max-width: 100%; height: auto;">
    </div>
  </div>
</div>
')
