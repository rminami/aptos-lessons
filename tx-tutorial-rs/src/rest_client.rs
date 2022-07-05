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
}
