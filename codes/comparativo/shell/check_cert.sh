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
