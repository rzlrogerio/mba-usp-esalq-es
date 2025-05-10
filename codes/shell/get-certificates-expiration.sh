#!/bin/sh

# Diretório dos certificados
DIR="/data/scripts-monitoring/bupf/certificados/cert"

# Variáveis do Zabbix
ZBXPRX_US_01=$(echo $ZBXPRX_US_01)
ZBXSRV=$(echo $ZBXSRV)
ZABBIX_API="$ZBXSRV/zabbix/api_jsonrpc.php"
ZBXSND=$(which zabbix_sender)
PRX_ID=$(echo $PRX_ID)

JSON_AUTH=$(mktemp --suffix=-ZABBIX-CERT-STATUS)
JSON_HOST=$(mktemp --suffix=-ZABBIX-CERT-STATUS-HOSTS)

GRP_ID="3201"
TEMPLATE_ID="10926"
KEY="cert_expiration"

# Senhas
JKS_SPB_BANK=$(echo $JKS_SPB_BANK)
PFX_SPB_BANK_PRODUCAO=$(echo $PFX_SPB_BANK_PRODUCAO)
PFX_SPB_BANK_HOMOLOGACAO=$(echo $PFX_SPB_BANK_HOMOLOGACAO)

CERT_TEMP="/tmp/certlist-temp"

cleanup() {
  rm -f "$JSON_AUTH" "$JSON_HOST" "$CERT_TEMP"
}
trap cleanup EXIT

fn_send_zabbix() {
  $ZBXSND -z "$ZBXPRX_US_01" -s "$AGR" -k "$KEY" -o "$EXP_DAYS"
}

fn_create_host() {
  cat > "$JSON_AUTH" <<END
{
  "jsonrpc": "2.0",
  "method": "user.login",
  "params": {
    "user": "$ZABBIX_USER",
    "password": "$ZABBIX_PASS"
  },
  "id": 1,
  "auth": null
}
END

  TOKEN=$(curl -s -X POST -H 'Content-Type:application/json' -d@"$JSON_AUTH" "$ZABBIX_API" | jq -r '.result')

  cat > "$JSON_HOST" <<END
{
  "jsonrpc": "2.0",
  "method": "host.create",
  "params": {
    "host": "$AGR",
    "interfaces": [
      {
        "type": 1,
        "main": 1,
        "useip": 1,
        "ip": "127.0.0.1",
        "dns": "$AGR",
        "port": "10050"
      }
    ],
    "groups": [
      {
        "groupid": "$GRP_ID"
      }
    ],
    "templates": [
      {
        "templateid": "$TEMPLATE_ID"
      }
    ]
  },
  "id": 1,
  "auth": "$TOKEN"
}
END

  curl -s -X POST -H 'Content-Type: application/json-rpc' -d@"$JSON_HOST" "$ZABBIX_API" > /dev/null
  curl -s --data "proxy_hostid=$PRX_ID&host=$AGR" -X POST "$ZBXSRV/zabbix-balancer/ws/update-zabbix-proxy.php" > /dev/null
}

fn_check_days() {
  local file="$1"
  local expiry_date="$2"
  local now_epoch expiry_epoch

  now_epoch=$(date +%s)
  expiry_epoch=$(date -d "$expiry_date" +%s)
  EXP_DAYS=$(( (expiry_epoch - now_epoch) / (3600 * 24) ))

  AGR=$(echo "$file" | awk -F'certificados/' '{ print $2 }' | sed 's/\//-/g')

  fn_create_host
  fn_send_zabbix
}

fn_process_certificates() {
  for file in $(find "$DIR" -type f \( -name "*.cer" -o -name "*.crt" -o -name "*.pem" \)); do
    expiry_date=$(openssl x509 -in "$file" -noout -enddate | cut -d= -f2)
    fn_check_days "$file" "$expiry_date"
  done
}

fn_process_jks() {
  for file in $(find "$DIR" -type f -name "*.jks"); do
    keytool -list -keystore "$file" -storepass "$JKS_SPB_BANK" | grep 'Alias name:' | awk -F': ' '{print $2}' > "$CERT_TEMP"

    while IFS= read -r alias; do
      expiry_date=$(keytool -list -keystore "$file" -storepass "$JKS_SPB_BANK" -alias "$alias" | grep 'until:' | awk -F'until: ' '{print $2}')
      AGR=$(echo "$file" | awk -F'certificados/' '{ print $2 }' | sed 's/\//-/g')-$(echo "$alias" | sed 's/[ .()]/-/g')
      fn_check_days "$file" "$expiry_date"
    done < "$CERT_TEMP"
  done
}

fn_process_pfx() {
  for file in $(find "$DIR" -type f -name "*.pfx"); do
    dir_name=$(basename "$(dirname "$file")")
    if [ "$dir_name" = "producao" ]; then
      PFX_SPB_BANK="$PFX_SPB_BANK_PRODUCAO"
    else
      PFX_SPB_BANK="$PFX_SPB_BANK_HOMOLOGACAO"
    fi

    expiry_date=$(openssl pkcs12 -in "$file" -clcerts -nokeys -passin pass:"$PFX_SPB_BANK" | openssl x509 -noout -enddate | cut -d= -f2)
    fn_check_days "$file" "$expiry_date"
  done
}

fn_main() {
  fn_process_certificates
  fn_process_jks
  fn_process_pfx
}

# Executa o script principal
fn_main
