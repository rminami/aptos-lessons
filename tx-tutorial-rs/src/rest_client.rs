use std::time::{SystemTime, UNIX_EPOCH};

use ed25519_dalek::{ExpandedSecretKey, PublicKey};
use hex::ToHex;

use crate::account::Account;

#[derive(Clone)]
pub struct RestClient {
    url: String,
}

impl RestClient {
    pub fn new(url: String) -> Self {
        Self { url }
    }

    pub fn account(&self, account_address: &str) -> serde_json::Value {
        let res =
            reqwest::blocking::get(format!("{}/accounts/{}", self.url, account_address)).unwrap();

        if res.status() != 200 {
            assert_eq!(
                res.status(),
                200,
                "{}-{}",
                res.text().unwrap_or_else(|_| "".to_string()),
                account_address
            );
        }

        res.json().unwrap()
    }

    pub fn account_resource(
        &self,
        account_address: &str,
        resource_type: &str,
    ) -> Option<serde_json::Value> {
        let res = reqwest::blocking::get(format!(
            "{}/accounts/{}/resource/{}",
            self.url, account_address, resource_type
        ))
        .unwrap();

        if res.status() == 404 {
            None
        } else if res.status() != 200 {
            assert_eq!(
                res.status(),
                200,
                "{}-{}",
                res.text().unwrap_or_else(|_| "".to_string()),
                account_address
            );
            unreachable!()
        } else {
            Some(res.json().unwrap())
        }
    }

    pub fn generate_transaction(
        &self,
        sender: &str,
        payload: serde_json::Value,
    ) -> serde_json::Value {
        let account_res = self.account(sender);

        let seq_num = account_res
            .get("sequence_number")
            .unwrap()
            .as_str()
            .unwrap()
            .parse::<u64>()
            .unwrap();

        let expiration_time_secs = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("Time went backwards")
            .as_secs()
            + 600;

        serde_json::json!({
            "sender": format!("0x{}", sender),
            "sequence_number": seq_num.to_string(),
            "max_gas_amount": "1000",
            "gas_unit_price": "1",
            "gas_currency_code": "XUS",
            "expiration_timestamp_secs": expiration_time_secs.to_string(),
            "payload": payload
        })
    }

    pub fn sign_transaction(
        &self,
        account_from: &mut Account,
        mut txn_request: serde_json::Value,
    ) -> serde_json::Value {
        let res = reqwest::blocking::Client::new()
            .post(format!("{}/transactions/signing_message", self.url))
            .body(txn_request.to_string())
            .send()
            .unwrap();

        if res.status() != 200 {
            assert_eq!(
                res.status(),
                200,
                "{} - {}",
                res.text().unwrap_or(String::from("")),
                txn_request.as_str().unwrap_or("")
            );
        }

        let body: serde_json::Value = res.json().unwrap();
        let to_sign_hex = Box::new(body.get("message").unwrap().as_str()).unwrap();
        let to_sign = hex::decode(&to_sign_hex[2..]).unwrap();
        let signature: String = ExpandedSecretKey::from(&account_from.signing_key)
            .sign(&to_sign, &PublicKey::from(&account_from.signing_key))
            .encode_hex();

        let signature_payload = serde_json::json!({
            "type": "ed25519_signature",
            "public_key": format!("0x{}", account_from.pub_key()),
            "signature": format!("0x{}", signature)
        });

        txn_request
            .as_object_mut()
            .unwrap()
            .insert("signature".to_string(), signature_payload);
        txn_request
    }
}
