address 0x1 {
module Country {
    struct Country {
        id: u8,
        population: u64
    }
    
    public fun new_country(c_id: u8, c_population: u64) {
        let country = Country {
            id: c_id,
            population: c_population
        };
        
        country
    }
    
    public fun id(country: &Country): u8 {
        country.id
    }

    public fun population(country: &Country): u8 {
        country.population
    }
}
}