use std::env;
use std::fs;
use std::path::Path;
use chrono::{DateTime, Utc};
use openssl::x509::X509;
use reqwest::blocking::Client;
use serde_json::json;

const DIR: &str = "/data/certificados";
const GRP_ID: &str = "3201";
const TEMPLATE_ID: &str = "10926";
const KEY: &str = "cert_expiration";

fn send_to_zabbix(client: &Client, zabbix_api: &str, agr: &str, exp_days: i64) {
    let payload = json!({
        "jsonrpc": "2.0",
        "method": "item.create",
        "params": {
            "host": agr,
            "key_": KEY,
            "value_type": 3,
            "delay": "30s",
            "history": "7d",
            "trends": "365d",
            "units": "days",
            "description": format!("Certificate expiration in {} days", exp_days),
        },
        "auth": null,
        "id": 1,
    });

    let response = client.post(zabbix_api).json(&payload).send();
    if let Err(err) = response {
        eprintln!("Failed to send data to Zabbix: {}", err);
    }
}

fn create_host(client: &Client, zabbix_api: &str, zabbix_user: &str, zabbix_pass: &str, agr: &str) {
    let auth_payload = json!({
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "user": zabbix_user,
            "password": zabbix_pass
        },
        "id": 1,
        "auth": null
    });

    let auth_response: serde_json::Value = client
        .post(zabbix_api)
        .json(&auth_payload)
        .send()
        .expect("Failed to authenticate with Zabbix API")
        .json()
        .expect("Failed to parse authentication response");

    let token = auth_response["result"].as_str().expect("No token received");

    let host_payload = json!({
        "jsonrpc": "2.0",
        "method": "host.create",
        "params": {
            "host": agr,
            "interfaces": [{
                "type": 1,
                "main": 1,
                "useip": 1,
                "ip": "127.0.0.1",
                "dns": agr,
                "port": "10050"
            }],
            "groups": [{
                "groupid": GRP_ID
            }],
            "templates": [{
                "templateid": TEMPLATE_ID
            }]
        },
        "id": 1,
        "auth": token
    });

    client
        .post(zabbix_api)
        .json(&host_payload)
        .send()
        .expect("Failed to create host in Zabbix");
}

fn check_days(file_path: &Path, expiry_date: DateTime<Utc>, client: &Client, zabbix_api: &str, zabbix_user: &str, zabbix_pass: &str) {
    let now = Utc::now();
    let exp_days = (expiry_date - now).num_days();

    let agr = file_path
        .strip_prefix(DIR)
        .unwrap()
        .to_str()
        .unwrap()
        .replace("/", "-");

    create_host(client, zabbix_api, zabbix_user, zabbix_pass, &agr);
    send_to_zabbix(client, zabbix_api, &agr, exp_days);
}

fn process_certificates(client: &Client, zabbix_api: &str, zabbix_user: &str, zabbix_pass: &str) {
    for entry in fs::read_dir(DIR).expect("Failed to read directory") {
        let entry = entry.expect("Failed to read entry");
        let path = entry.path();

        if path.is_file() {
            if let Some(ext) = path.extension() {
                if ext == "cer" {
                    let cert_data = fs::read(&path).expect("Failed to read certificate file");
                    let cert = X509::from_pem(&cert_data).expect("Failed to parse certificate");
                    let expiry_date = cert.not_after().to_string();
                    let expiry_date = DateTime::parse_from_rfc2822(&expiry_date)
                        .expect("Failed to parse expiry date")
                        .with_timezone(&Utc);

                    check_days(&path, expiry_date, client, zabbix_api, zabbix_user, zabbix_pass);
                }
            }
        }
    }
}

fn main() {
    let zbx_server = env::var("ZBXSRV").expect("ZBXSRV not set");
    let zabbix_api = format!("{}/zabbix/api_jsonrpc.php", zbx_server);
    let zabbix_user = env::var("ZABBIX_USER").expect("ZABBIX_USER not set");
    let zabbix_pass = env::var("ZABBIX_PASS").expect("ZABBIX_PASS not set");

    let client = Client::new();

    process_certificates(&client, &zabbix_api, &zabbix_user, &zabbix_pass);
}
