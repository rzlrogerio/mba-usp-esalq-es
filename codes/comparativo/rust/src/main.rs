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
    // Normalize timezone names like "GMT"/"UTC" to numeric offset "+0000"
    let mut expiry_norm = expiry_str.clone();
    if expiry_norm.ends_with(" GMT") {
        expiry_norm = expiry_norm.trim_end_matches(" GMT").to_string() + " +0000";
    } else if expiry_norm.ends_with(" UTC") {
        expiry_norm = expiry_norm.trim_end_matches(" UTC").to_string() + " +0000";
    }

    let expiry = DateTime::parse_from_str(&expiry_norm, "%b %e %H:%M:%S %Y %z")
        .or_else(|_| DateTime::parse_from_str(&expiry_norm, "%b %d %H:%M:%S %Y %z"))
        .or_else(|_| DateTime::parse_from_rfc2822(&expiry_norm))
        .or_else(|_| DateTime::parse_from_str(&expiry_norm, "%Y%m%d%H%M%SZ"))
        .unwrap_or_else(|_| {
            eprintln!("Falha ao parsear data: '{}'", expiry_str);
            process::exit(1);
        })
        .with_timezone(&Utc);
    let days = (expiry - Utc::now()).num_days();
    println!("Rust: O certificado expira em {} dias.", days);
}
