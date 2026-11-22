// Ajudantes dos gráficos (Highcharts), chamados nos eventos `render` dos
// gráficos definidos em server.R. Seguem as receitas do design system.
window.VT = window.VT || {};

// Remove os rótulos desenhados no render anterior (o render roda de novo a
// cada redimensionamento ou ao esconder uma série).
VT.limpar = function (chart) {
  (chart.vtRotulos || []).forEach(function (r) { r.destroy(); });
  chart.vtRotulos = [];
};

// Receita 2: nome da série logo depois do último ponto, na cor da série, sem
// legenda. Rótulos a menos de 18 px na vertical são afastados. Nas colunas
// empilhadas, o rótulo fica ao lado do meio do último segmento.
VT.rotulosFinais = function () {
  var chart = this, itens = [], min = 18;
  VT.limpar(chart);
  // No celular (regra "responsive" em graficos.R) a legenda substitui os nomes
  if (chart.legend && chart.legend.options.enabled) return;
  chart.series.forEach(function (s) {
    if (!s.visible || s.options.vtSemRotulo) return;
    var coluna = s.type === 'column' || s.type === 'bar';
    var pts = s.points.filter(function (p) { return !p.isNull && p.plotY !== undefined && !(coluna && !p.y); });
    if (!pts.length) return;
    var p = pts[pts.length - 1], x, y;
    if (p.shapeArgs && coluna) {
      x = chart.plotLeft + p.shapeArgs.x + p.shapeArgs.width + 8;
      y = chart.plotTop + p.shapeArgs.y + p.shapeArgs.height / 2;
    } else {
      x = chart.plotLeft + p.plotX + 10;
      y = chart.plotTop + p.plotY;
    }
    itens.push({ s: s, x: x, y: y });
  });
  itens.sort(function (a, b) { return a.y - b.y; });
  for (var i = 1; i < itens.length; i++) {
    if (itens[i].y - itens[i - 1].y < min) itens[i].y = itens[i - 1].y + min;
  }
  var fundo = chart.plotTop + chart.plotHeight;
  for (var j = itens.length - 1; j >= 0; j--) {
    var limite = j === itens.length - 1 ? fundo : itens[j + 1].y - min;
    if (itens[j].y > limite) itens[j].y = limite;
  }
  itens.forEach(function (it) {
    var cor = it.s.options.vtCorRotulo || it.s.color;
    chart.vtRotulos.push(
      chart.renderer.text(it.s.name, it.x, it.y + 5)
        .css({ color: cor, fontWeight: '600', fontSize: '14px' })
        .attr({ zIndex: 6 }).add()
    );
  });
};

// Pirâmide: o nome de cada sexo no alto do seu lado, na cor da série.
VT.rotulosLados = function () {
  var chart = this;
  VT.limpar(chart);
  var y = chart.plotTop + 14;
  [[0, chart.plotLeft + 4, 'left'], [1, chart.plotLeft + chart.plotWidth - 4, 'right']].forEach(function (l) {
    var s = chart.series[l[0]];
    if (!s) return;
    chart.vtRotulos.push(
      chart.renderer.text(s.name, l[1], y)
        .css({ color: s.color, fontWeight: '600', fontSize: '14px' })
        .attr({ align: l[2], zIndex: 6 }).add()
    );
  });
};

// Eixo da pirâmide: valor absoluto (os homens ficam à esquerda, negativos),
// com "mil" a partir de 1.000.
VT.rotuloAbs = function () {
  var v = Math.abs(this.value);
  if (v < 1000) return VT.num(v);
  var k = v / 1000;
  return VT.num(k, k % 1 ? 1 : 0) + ' mil';
};

// Mapa de calor (Highcharts 9.3): depois que o gráfico muda de tamanho, o caminho
// (shapeArgs.d) de cada célula continua com a geometria antiga. No hover, o
// Highcharts redesenha a célula por esse caminho e ela "cai" sobre as vizinhas.
// Refaz o caminho a partir da posição e do tamanho atuais, a cada desenho.
VT.calorSemSalto = function () {
  this.series.forEach(function (s) {
    if (s.type !== 'heatmap') return;
    s.points.forEach(function (p) {
      var a = p.shapeArgs;
      if (!a || a.d === undefined) return;
      a.d = [['M', a.x, a.y], ['L', a.x + a.width, a.y], ['L', a.x + a.width, a.y + a.height],
             ['L', a.x, a.y + a.height], ['Z']];
    });
  });
};

// Números no padrão brasileiro (para formatadores em JS).
VT.num = function (x, casas) {
  return Highcharts.numberFormat(x, casas === undefined ? 0 : casas, ',', '.');
};

// Celular: os filtros ficam acima do gráfico; ao clicar em "Atualizar gráfico",
// a página rola até o gráfico.
$(document).on('click', '.bslib-sidebar-layout > .sidebar .btn-primary', function () {
  if (window.innerWidth >= 576) return;
  var main = $(this).closest('.bslib-sidebar-layout').children('.main').get(0);
  if (main) main.scrollIntoView({ behavior: 'smooth', block: 'start' });
});
