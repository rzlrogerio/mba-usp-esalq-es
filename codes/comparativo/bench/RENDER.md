Instruções para renderizar o gráfico de comparação de desempenho gerado a partir de `resultado.txt`.

Gerar PNG (recomendado):

```bash
dot -Tpng bench/result_comparison.dot -o bench/result_comparison.png
```

Gerar SVG:

```bash
dot -Tsvg bench/result_comparison.dot -o bench/result_comparison.svg
```

Observações:
- O arquivo `.dot` usa altura dos nós em polegadas proporcional ao valor médio (ms). Se quiser ajustar escala, edite os atributos `height` em `bench/result_comparison.dot`.
