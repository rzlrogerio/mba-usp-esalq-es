# Etapa de build
FROM rust:1.77 as builder

WORKDIR /usr/src/app
COPY . .

RUN cargo build --release

# Etapa de runtime
FROM debian:buster-slim

WORKDIR /app
COPY --from=builder /usr/src/app/target/release/main /app/main

# Se precisar de libs adicionais, instale aqui
# RUN apt-get update && apt-get install -y libssl1.1

CMD ["./main"]
