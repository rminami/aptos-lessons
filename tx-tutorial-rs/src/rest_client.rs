#[derive(Clone)]
pub struct RestClient {
    url: String,
}

impl RestClient {
    pub fn new(url: String) -> Self {
        Self { url }
    }
}
