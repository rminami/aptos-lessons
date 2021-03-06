module NamedAddr::BasicCoin {
    use std::signer;
    
    // Address of the owner of this module
    const MODULE_OWNER: address = @NamedAddr;
    
    // Error codes
    const ENOT_MODULE_OWNER: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EALREADY_HAS_BALANCE: u64 = 2;
    const EEQUAL_ADDR: u64 = 3;
    
    struct Coin<phantom CoinType> has key, store {
        value: u64,
    }
    
    struct Balance<phantom CoinType> has key {
        coin: Coin<CoinType>,
    }
    
    // Publish an empty balance resource under `account`'s address.
    // This function must be called before minting or transferring to the account.
    public fun publish_balance<CoinType>(account: &signer) {
        // Check that `account` doesn't have a `Balance` resource.
        assert!(!exists<Balance<CoinType>>(signer::address_of(account)), EALREADY_HAS_BALANCE);

        let empty_coin = Coin<CoinType> { value: 0 };
        move_to(account, Balance { coin: empty_coin });
    }
    
    spec publish_balance {
        include Schema_publish<CoinType> { addr: signer::address_of(account), amount: 0 };
    }
    
    spec schema Schema_publish<CoinType> {
        addr: address;
        amount: u64;
        
        aborts_if exists<Balance<CoinType>>(addr);
        
        ensures exists<Balance<CoinType>>(addr);
        let post balance_post = global<Balance<CoinType>>(addr).coin.value;
        
        ensures balance_post == amount;
    }
    
    // Mint `amount` tokens to `mint_addr`. Mint must be approved by the module owner.
    public fun mint<CoinType: drop>(mint_addr: address, amount: u64, _witness: CoinType) acquires Balance {
        // Deposit `amount` of tokens to `mint_addr`'s balance
        deposit<CoinType>(mint_addr, Coin { value: amount });
    }
    
    spec mint {
        include DepositSchema<CoinType> { addr: mint_addr, amount };
    }

    // Returns the balance of `owner`.
    public fun balance_of<CoinType>(owner: address): u64 acquires Balance {
        borrow_global<Balance<CoinType>>(owner).coin.value
    }
    
    spec balance_of {
        pragma aborts_if_is_strict;
        aborts_if !exists<Balance<CoinType>>(owner);
    }
    
    // Transfers `amount` of tokens from `from` to `to`.
    public fun transfer<CoinType: drop>(from: &signer, to: address, amount: u64, _witness: CoinType) acquires Balance {
        let from_addr = signer::address_of(from);
        assert!(from_addr != to, EEQUAL_ADDR);
        
        let check = withdraw<CoinType>(signer::address_of(from), amount);
        deposit<CoinType>(to, check);
    }
    
    spec transfer {
        let addr_from = signer::address_of(from);
        
        let balance_from = global<Balance<CoinType>>(addr_from).coin.value;
        let balance_to = global<Balance<CoinType>>(to).coin.value;
        
        let post balance_from_post = global<Balance<CoinType>>(addr_from).coin.value;
        let post balance_to_post = global<Balance<CoinType>>(to).coin.value;
        
        aborts_if !exists<Balance<CoinType>>(addr_from);
        aborts_if !exists<Balance<CoinType>>(to);
        aborts_if balance_from < amount;
        aborts_if balance_to + amount > MAX_U64;
        aborts_if addr_from == to;
        
        ensures balance_from_post == balance_from - amount;
        ensures balance_to_post == balance_to + amount;
    }
    
    fun withdraw<CoinType>(addr: address, amount: u64): Coin<CoinType> acquires Balance {
        let balance = balance_of<CoinType>(addr);
        
        // balance must be greater than the withdraw amount
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);
        
        let balance_ref = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        *balance_ref = balance - amount;
        Coin { value: amount }
    }
    
    spec withdraw {
        let balance = global<Balance<CoinType>>(addr).coin.value;
        aborts_if !exists<Balance<CoinType>>(addr);
        aborts_if balance < amount;
        
        let post balance_post = global<Balance<CoinType>>(addr).coin.value;
        ensures balance_post == balance - amount;
        ensures result == Coin<CoinType> { value: amount };
    }
    
    fun deposit<CoinType>(addr: address, check: Coin<CoinType>) acquires Balance {
        let balance = balance_of<CoinType>(addr);
        
        let balance_ref = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        let Coin { value } = check;
        *balance_ref = balance + value;
    }
    
    spec deposit {
        let balance = global<Balance<CoinType>>(addr).coin.value;
        let check_value = check.value;
        
        aborts_if !exists<Balance<CoinType>>(addr);
        aborts_if balance + check_value > MAX_U64;
        
        let post balance_post = global<Balance<CoinType>>(addr).coin.value;
        ensures balance_post == balance + check_value;
    }

    spec schema DepositSchema<CoinType> {
        addr: address;
        amount: u64;
        let balance = global<Balance<CoinType>>(addr).coin.value;

        aborts_if !exists<Balance<CoinType>>(addr);
        aborts_if balance + amount > MAX_U64;

        let post balance_post = global<Balance<CoinType>>(addr).coin.value;
        ensures balance_post == balance + amount;
    }

    // #[test(account = @0x1)]
    // #[expected_failure]
    // fun mint_non_owner(account: signer) acquires Balance {
    //     // Make sure the address we've chosen doesn't match the module owner address.
    //     publish_balance(&account);
    //     assert!(signer::address_of(&account) != MODULE_OWNER, 0);
    //     mint(&account, @0x1, 10);
    // }
    
    // #[test(account = @NamedAddr)]
    // fun mint_check_balance(account: signer) acquires Balance {
    //     let addr = signer::address_of(&account);
    //     publish_balance(&account);
    //     mint(&account, @NamedAddr, 42);
    //     assert!(balance_of(addr) == 42, 0);
    // }
    
    // #[test(account = @0x1)]
    // fun publish_balance_has_zero(account: signer) acquires Balance {
    //     let addr = signer::address_of(&account);
    //     publish_balance(&account);
    //     assert!(balance_of(addr) == 0, 0);
    // }
    
    // #[test(account = @0x1)]
    // #[expected_failure(abort_code = 2)]
    // fun publish_balance_already_exists(account: signer) {
    //     publish_balance(&account);
    //     publish_balance(&account);
    // }
    
    // #[test]
    // #[expected_failure]
    // fun balance_dne() acquires Balance {
    //     balance_of(@0x1);
    // }
    
    // #[test]
    // #[expected_failure]
    // fun withdraw_dne() acquires Balance {
    //     // Need to unpack the coin since `Coin` is a resource
    //     Coin { value: _ } = withdraw(@0x1, 0);
    // }
    
    // #[test(account = @0x1)]
    // #[expected_failure]
    // fun withdraw_too_much(account: signer) acquires Balance {
    //     let addr = signer::address_of(&account);
    //     publish_balance(&account);
    //     Coin { value: _ } = withdraw(addr, 1);
    // }
    
    // #[test(account = @NamedAddr)]
    // fun can_withdraw_amount(account: signer) acquires Balance {
    //     publish_balance(&account);
    //     let amount = 1000;
    //     let addr = signer::address_of(&account);
    //     mint(&account, addr, amount);
    //     let Coin { value } = withdraw(addr, amount);
    //     assert!(value == amount, 0);
    // }
}


