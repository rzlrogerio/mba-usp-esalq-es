#!/bin/bash
set -e

# 1. Criar estrutura de diretórios
echo "Criando diretórios..."
mkdir -p comparativo/certs
mkdir -p comparativo/shell
mkdir -p comparativo/rust/src

# 2. Criar certificado válido por 25 dias
echo "Gerando certificado válido por 25 dias..."
openssl req -x509 -newkey rsa:2048 \
  -keyout comparativo/certs/key.pem \
  -out comparativo/certs/cert.pem \
  -days 25 -nodes \
  -subj "/C=BR/ST=SP/L=Sao Paulo/O=Teste/CN=comparativo.local" 2>/dev/null

# 3. Criar script Shell para validação
echo "Criando script Shell..."
cat << 'EOF' > comparativo/shell/check_cert.sh
#!/bin/bash
if [ -z "$1" ]; then
    echo "Uso: $0 <caminho_do_certificado>"
    exit 1
fi
CERT="$1"
if [ -f "$CERT" ]; then
    END_DATE=$(openssl x509 -enddate -noout -in "$CERT" | cut -d= -f2)
    # date -d funciona bem em Linux (GNU date).
    END_EPOCH=$(date -d "$END_DATE" +%s)
    NOW_EPOCH=$(date +%s)
    DAYS=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))
    echo "Shell: O certificado expira em $DAYS dias."
else
    echo "Erro: Certificado não encontrado: $CERT"
fi
EOF
chmod +x comparativo/shell/check_cert.sh

# 4. Criar programa Rust para validação
echo "Criando programa Rust..."
cat << 'EOF' > comparativo/rust/Cargo.toml
[package]
name = "check_cert_rust"
version = "0.1.0"
edition = "2021"

[dependencies]
chrono = "0.4"
openssl = "0.10"
EOF

cat << 'EOF' > comparativo/rust/src/main.rs
use std::fs;
use std::env;
use std::process;
use chrono::{DateTime, Utc};
use openssl::x509::X509;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Uso: {} <caminho_do_certificado>", args[0]);
        process::exit(1);
    }
    let cert_path = &args[1];
    let data = fs::read(cert_path).expect("Falha ao ler certificado");
    let cert = X509::from_pem(&data).expect("Falha ao parsear PEM");
    let expiry_str = cert.not_after().to_string();
    let expiry = DateTime::parse_from_str(&expiry_str, "%b %d %H:%M:%S %Y %Z")
        .or_else(|_| DateTime::parse_from_str(&expiry_str, "%b %e %H:%M:%S %Y %Z"))
        .or_else(|_| DateTime::parse_from_rfc2822(&expiry_str))
        .expect(&format!("Falha ao parsear data: '{}'", expiry_str))
        .with_timezone(&Utc);
    let days = (expiry - Utc::now()).num_days();
    println!("Rust: O certificado expira em {} dias.", days);
}
EOF

# 5. Compilar o binário Rust
echo "Compilando o binário Rust (modo release)..."
(cd comparativo/rust && cargo build --release)

echo "Ambiente criado com sucesso em ./comparativo"
echo ""
echo "Para executar a validação:"
echo "  1. Shell Script:"
echo "     ./comparativo/shell/check_cert.sh comparativo/certs/cert.pem"
echo "  2. Rust (Binário direto):"
echo "     ./comparativo/rust/target/release/check_cert_rust comparativo/certs/cert.pem"
echo "  3. Rust (Desenvolvimento):"
echo "     (cd comparativo/rust && cargo run -- ../certs/cert.pem)"