module owner::erc20 {

    use std::option;
    use std::option::Option;
    use std::signer;
    use std::string::{utf8};
    use std::vector;

    use aptos_std::smart_table;
    use aptos_std::smart_table::SmartTable;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;

    use aptos_framework::event;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{MintRef, BurnRef, TransferRef, Metadata};
    use aptos_framework::object;
    use aptos_framework::object::{ConstructorRef, Object};
    use aptos_framework::primary_fungible_store;

    // Errors.

    /// Error when not an admin vault
    const E_NOT_ADMIN: u64 = 1;
    /// Error when an account has no tokens
    const E_ACCOUNT_HAS_NO_TOKENS: u64 = 2;
    /// Error when system is paused
    const E_PAUSED: u64 = 3;
    /// Error when creator token is currently paused
    const E_PAUSED_CREATOR_TOKEN: u64 = 4;
    /// Error when a token already exists
    const E_TOKEN_ALREADY_EXISTS: u64 = 5;
    /// Error when the account does not own the specified token
    const E_ACCOUNT_NOT_OWNED_TOKEN: u64 = 6;
    /// Error when the provided amount is invalid
    const E_INVALID_AMOUNT: u64 = 7;
    /// Error wwhen the account has insufficient balance to burn the specified amount
    const E_NOT_ENOUGH_BALANCE_TO_BURN: u64 = 8;
    /// Error when the account has insufficient balance to transfer the specified amount
    const E_NOT_ENOUGH_BALANCE_TO_TRANSFER: u64 = 9;
    /// Error when the account has insufficient balance to create a new token
    const E_NOT_BALANCE_TO_CREATE_TOKEN: u64 = 10;


    // Constants.
    /// Address of the contract owner.
    const CONTRACT_ADDRESS: address = @owner;
    /// The fee required to create a new token.
    const FEE_CREATE_TOKEN: u64 = 100;


    // Structs.

    struct UserTokenManager has store {
        account: address,
        paused: bool,
        sym_to_addr: SmartTable<vector<u8>, address>,
        addr_to_sym: SmartTable<address, vector<u8>>,
    }

    struct TokenManager has key {
        admin: address,
        paused: bool,
        fee_to: coin::Coin<AptosCoin>,
        user_infos: SmartTable<address, UserTokenManager>,
        tokens_list: vector<address>
    }

    struct Management has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }

    // Events.

    #[event]
    struct CreateTokenEvent has drop, store {
        creator: address,
        token: address,
    }

    #[event]
    struct PauseEvent has drop, store {
        pauser: address,
        paused: bool,
    }

    #[event]
    struct PauseCreatorEvent has drop, store {
        pauser: address,
        creator: address,
        paused: bool,
    }

    #[event]
    struct MintTokenEvent has drop, store {
        minter: address,
        token: address,
        to: address,
        amount: u64,
    }

    #[event]
    struct BurnTokenEvent has drop, store {
        burner: address,
        token: address,
        from: address,
        amount: u64,
    }

    #[event]
    struct TransferTokenEvent has drop, store {
        from: address,
        token: address,
        to: address,
        amount: u64,
    }

    // Functions.

    fun init_module(owner: &signer) {
        move_to(
            owner,
            TokenManager {
                admin: @admin,
                paused: false,
                fee_to: coin::zero<AptosCoin>(),
                user_infos: smart_table::new(),
                tokens_list: vector::empty<address>()
            }
        );
    }

    // Admin functions.

    public entry fun set_admin(admin: &signer, new_admin: address) acquires TokenManager {
        let token_manager: &mut TokenManager = borrow_global_mut<TokenManager>(CONTRACT_ADDRESS);
        assert!(signer::address_of(admin) == token_manager.admin, E_NOT_ADMIN);
        token_manager.admin = new_admin;
    }

    public entry fun set_pause(admin: &signer, paused: bool) acquires TokenManager {
        let token_manager: &mut TokenManager = borrow_global_mut<TokenManager>(CONTRACT_ADDRESS);
        assert!(signer::address_of(admin) == token_manager.admin, E_NOT_ADMIN);
        if (token_manager.paused == paused) {
            return
        };

        token_manager.paused = paused;
        event::emit(PauseEvent {
            pauser: token_manager.admin,
            paused
        });
    }

    public entry fun set_pause_creator(admin: &signer, account: address, paused: bool) acquires TokenManager {
        let token_manager: &mut TokenManager = borrow_global_mut<TokenManager>(CONTRACT_ADDRESS);
        assert!(signer::address_of(admin) == token_manager.admin, E_NOT_ADMIN);
        assert!(smart_table::contains(&token_manager.user_infos, account), E_ACCOUNT_HAS_NO_TOKENS);
        if (smart_table::borrow(&token_manager.user_infos, account).paused == paused) {
            return
        };

        smart_table::borrow_mut(&mut token_manager.user_infos, account).paused = paused;
        event::emit(PauseCreatorEvent {
            pauser: token_manager.admin,
            creator: account,
            paused,
        })
    }

    // User functions.

    public entry fun create_token(
        creator: &signer,
        maximum_supply: Option<u128>,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        icon_uri: vector<u8>,
        project_uri: vector<u8>,
    ) acquires TokenManager {
        let creator_address: address = signer::address_of(creator);
        let token_manager: &mut TokenManager = borrow_global_mut<TokenManager>(CONTRACT_ADDRESS);
        // Token creation must be restricted exclusively to the admin account.
        // assert!(creator_address == token_registry.admin, E_NOT_ADMIN);

        assert!(!token_manager.paused, E_PAUSED);
        // assert!(coin::balance<AptosCoin>(creator_address) >= FEE_CREATE_TOKEN, E_NOT_BALANCE_TO_CREATE_TOKEN);
        if (!smart_table::contains(&token_manager.user_infos, creator_address)) {
            let user_token_manager: UserTokenManager = UserTokenManager {
                account: creator_address,
                paused: false,
                sym_to_addr: smart_table::new<vector<u8>, address>(),
                addr_to_sym: smart_table::new<address, vector<u8>>()
            };
            smart_table::add(&mut token_manager.user_infos, creator_address, user_token_manager);
        };

        assert!(!smart_table::contains(&smart_table::borrow(&mut token_manager.user_infos, creator_address).sym_to_addr, symbol), E_TOKEN_ALREADY_EXISTS);
        assert!(!smart_table::borrow(&mut token_manager.user_infos, creator_address).paused, E_PAUSED_CREATOR_TOKEN);

        let constructor_ref: ConstructorRef = object::create_named_object(creator, symbol);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            maximum_supply,
            utf8(name),
            utf8(symbol),
            decimals,
            utf8(icon_uri),
            utf8(project_uri)
        );

        let token_address: address = object::create_object_address(&creator_address, symbol);

        smart_table::add(
            &mut smart_table::borrow_mut(&mut token_manager.user_infos, creator_address).sym_to_addr,
            symbol,
            token_address,
        );

        smart_table::add(
            &mut smart_table::borrow_mut(&mut token_manager.user_infos, creator_address).addr_to_sym,
            token_address,
            symbol
        );

        vector::push_back(&mut token_manager.tokens_list, token_address);

        let token_signer: signer = object::generate_signer(&constructor_ref);
        move_to(
            &token_signer,
            Management {
                mint_ref: fungible_asset::generate_mint_ref(&constructor_ref),
                burn_ref: fungible_asset::generate_burn_ref(&constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(&constructor_ref),
            }
        );

        // let fee_coin: coin::Coin<AptosCoin> = coin::withdraw<AptosCoin>(creator, FEE_CREATE_TOKEN);
        // coin::merge(&mut token_manager.fee_to, fee_coin);

        event::emit(CreateTokenEvent {
            creator: creator_address,
            token: token_address,
        });
    }

    public entry fun mint(
        minter: &signer,
        token: address,
        to: address,
        amount: u64,
    ) acquires TokenManager, Management {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        assert!(!token_manager.paused, E_PAUSED);

        let minter_address: address = signer::address_of(minter);
        assert!(smart_table::contains(&token_manager.user_infos, minter_address), E_ACCOUNT_HAS_NO_TOKENS);
        assert!(!smart_table::borrow(&token_manager.user_infos, minter_address).paused, E_PAUSED_CREATOR_TOKEN);
        assert!(
            smart_table::contains(&smart_table::borrow(&token_manager.user_infos, minter_address).addr_to_sym, token),
            E_ACCOUNT_NOT_OWNED_TOKEN
        );

        assert!(amount > 0, E_INVALID_AMOUNT);
        let management: &Management = borrow_global<Management>(token);
        primary_fungible_store::mint(
            &management.mint_ref,
            to,
            amount
        );

        event::emit(MintTokenEvent {
            minter: minter_address,
            token,
            to,
            amount,
        });
    }

    public entry fun burn(
        minter: &signer,
        token: address,
        from: address,
        amount: u64,
    ) acquires TokenManager, Management {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        assert!(!token_manager.paused, E_PAUSED);

        let minter_address: address = signer::address_of(minter);
        assert!(smart_table::contains(&token_manager.user_infos, minter_address), E_ACCOUNT_HAS_NO_TOKENS);
        assert!(!smart_table::borrow(&token_manager.user_infos, minter_address).paused, E_PAUSED_CREATOR_TOKEN);
        assert!(
            smart_table::contains(&smart_table::borrow(&token_manager.user_infos, minter_address).addr_to_sym, token),
            E_ACCOUNT_NOT_OWNED_TOKEN
        );

        let management: &Management = borrow_global<Management>(token);
        let metadata: Object<Metadata> = object::address_to_object(token);
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(primary_fungible_store::balance(from, metadata) >= amount, E_NOT_ENOUGH_BALANCE_TO_BURN);
        primary_fungible_store::burn(
            &management.burn_ref,
            from,
            amount
        );

        event::emit(BurnTokenEvent {
            burner: minter_address,
            token,
            from,
            amount,
        });
    }

    public entry fun transfer(
        sender: &signer,
        token: address,
        to: address,
        amount: u64
    ) acquires TokenManager, Management {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        assert!(!token_manager.paused, E_PAUSED);

        let sender_address: address = signer::address_of(sender);

        let management: &Management = borrow_global<Management>(token);
        let metadata: Object<Metadata> = object::address_to_object(token);
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(primary_fungible_store::balance(sender_address, metadata) >= amount, E_NOT_ENOUGH_BALANCE_TO_TRANSFER);
        primary_fungible_store::transfer_with_ref(
            &management.transfer_ref,
            sender_address,
            to,
            amount
        );

        event::emit(TransferTokenEvent {
            from: sender_address,
            token,
            to,
            amount,
        });
    }

    // View functions.

    public fun get_admin(): address acquires TokenManager {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        token_manager.admin
    }

    public fun is_paused(): bool acquires TokenManager {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        token_manager.paused
    }

    public fun is_creator_paused(account: address): bool acquires TokenManager {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        assert!(smart_table::contains(&token_manager.user_infos, account), E_ACCOUNT_HAS_NO_TOKENS);
        smart_table::borrow(&token_manager.user_infos, account).paused
    }

    public fun get_token_address(creator: address, symbol: vector<u8>): address acquires TokenManager {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        assert!(smart_table::contains(&token_manager.user_infos, creator), E_ACCOUNT_HAS_NO_TOKENS);
        assert!(smart_table::contains(&smart_table::borrow(&token_manager.user_infos, creator).sym_to_addr, symbol),
            E_ACCOUNT_NOT_OWNED_TOKEN
        );
        *smart_table::borrow(&smart_table::borrow(&token_manager.user_infos, creator).sym_to_addr, symbol)
    }

    public fun get_total_supply(token: address): u64 {
        let metadata: Object<Metadata> = object::address_to_object(token);
        let supply: Option<u128> = fungible_asset::supply(metadata);
        if (option::is_none(&supply)) {
            0
        } else (option::extract(&mut supply) as u64)
    }

    public fun get_owned_token(account: address): vector<address> acquires TokenManager {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        assert!(smart_table::contains(&token_manager.user_infos, account), E_ACCOUNT_HAS_NO_TOKENS);
        smart_table::keys(&smart_table::borrow(&token_manager.user_infos, account).addr_to_sym)
    }

    public fun get_tokens_list(): vector<address> acquires TokenManager {
        let token_manager: &TokenManager = borrow_global<TokenManager>(CONTRACT_ADDRESS);
        token_manager.tokens_list
    }

    // Test.

    #[test_only]
    public fun initialize(owner: &signer) {
        init_module(owner);
    }
}