# 🚀 Comparativo de desempenho — Shell vs Rust

[![Benchmark](https://img.shields.io/badge/benchmarks-comparativo-blue)](README.md) [![Language](https://img.shields.io/badge/language-Bash%20|%20Rust-orange)](README.md)

## 🔎 Descrição
- Repositório com duas implementações para checar expiração de certificado X.509:
  - `shell/check_cert.sh` (script Bash)
  - `rust/target/release/check_cert_rust` (binário Rust gerado a partir de `comparativo/rust`)

## 🎯 Objetivo
- Medir e comparar tempos (média, mínimo, máximo) das duas implementações sobre o mesmo certificado.

## ⚙️ Pré-requisitos
- Linux com Bash
- `cargo` (Rust) toolchain para compilar o binário
- Dependências OpenSSL (headers) para compilar o crate Rust

## 🧭 Sumário
- [Como compilar](#-como-compilar)
- [Como executar](#-como-executar)
- [Script de benchmark](#-script-de-benchmark)
- [Resultados](#-resultados)
- [Análise rápida](#-análise-rápida)

## 🛠️ Como compilar
Para compilar o binário Rust (no diretório `comparativo`):

```bash
cd comparativo/rust
cargo build --release
```

## ▶️ Como executar (individual)

- Script shell:

```bash
cd comparativo
./shell/check_cert.sh certs/cert.pem
```

- Binário Rust (após `cargo build --release`):

```bash
cd comparativo
./rust/target/release/check_cert_rust certs/cert.pem
```

## 🧪 Script de benchmark
O script está em `comparativo/bench/run_bench.sh`.

Uso padrão (executa 20 iterações):

```bash
cd comparativo
./bench/run_bench.sh certs/cert.pem 20
```

O script realiza `ITERS` execuções de cada programa e reporta médias, mínimos, máximos e um fator de speedup (média shell / média rust).

## 📊 Resultados (exemplo)
Saída do comando de benchmark (cada linha do resultado está separada por uma linha em branco para facilitar leitura):

```bash
$ ./bench/run_bench.sh certs/cert.pem

Benchmark (cert: certs/cert.pem, iterations: 20)

Shell: avg 18.685767 ms | min 14.103027 ms | max 96.303522 ms

Rust:  avg 4.190846 ms | min 3.857751 ms | max 5.015134 ms

Speedup: Rust is 4.46x faster (avg)
```

> Observação: acima usei linhas em branco entre cada linha de resultado para melhorar a legibilidade — se preferir, a saída pode ficar sem linhas extras (formato de bloco simples).

## 🧾 Resultado agregado (JSON)
- Consulte `benchmark_results.json` para os dados estruturados (média, min, max, median etc.).

## 🧠 Análise rápida
- Speedup médio (shell / rust): aproximadamente 7.5x (varia conforme execução).
- Há outliers (`max` > `median`), indicando possível ruído do sistema ou I/O.

## 📁 Arquivos relevantes
- `bench/run_bench.sh` — script de benchmark
- `benchmark_results.json` — resultados salvos
- `shell/check_cert.sh` — implementação em shell
- `rust/` — código fonte Rust

## ✉️ Contato
- Para dúvidas sobre reprodução dos testes, abra uma issue ou envie mensagem ao mantenedor.
