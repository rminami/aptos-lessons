address 0x1 {
module Library {
    struct Book has store, copy, drop {
        year: u64
    }
    
    struct Storage has key {
        books: vector<Book>
    }
    
    struct Empty {}
}
}