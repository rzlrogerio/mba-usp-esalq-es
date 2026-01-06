Graphviz: render do gráfico de desempenho

Renderize o arquivo DOT para PNG (exemplo):

```bash
dot -Tpng bench/performance_comparison.dot -o bench/performance_comparison.png
```

Ou gere SVG:

```bash
dot -Tsvg bench/performance_comparison.dot -o bench/performance_comparison.svg
```

Os valores usados no gráfico foram extraídos de `resultado.txt`.
