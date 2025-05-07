#[test_only]
module owner::erc20_test {

    use std::option;
    use std::signer;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use owner::erc20;

    #[test(creator = @owner)]
    fun test_init_success(creator: &signer) {
        erc20::initialize(creator);
    }

    #[test(creator = @owner, admin = @admin)]
    fun test_set_admin_success(creator: &signer, admin: &signer) {
        erc20::initialize(creator);
        erc20::set_admin(admin, @user);
        assert!(erc20::get_admin() == @user, 1);
    }

    #[test(creator = @owner)]
    #[expected_failure(abort_code = erc20::E_NOT_ADMIN, location = erc20)]
    fun test_set_admin_failed_when_not_admin(creator: &signer) {
        erc20::initialize(creator);
        erc20::set_admin(creator, @owner);
    }

    #[test(creator = @owner, admin = @admin)]
    #[expected_failure(abort_code = erc20::E_NOT_ADMIN, location = erc20)]
    fun test_set_admin_failed_when_not_new_admin(creator: &signer, admin: &signer) {
        erc20::initialize(creator);
        erc20::set_admin(admin, @owner);
        erc20::set_admin(admin, @user);
    }

    #[test(creator = @owner, admin = @admin)]
    fun test_set_pause_success(creator: &signer, admin: &signer) {
        erc20::initialize(creator);
        assert!(!erc20::is_paused(), 2);
        erc20::set_pause(admin, true);
        assert!(erc20::is_paused(), 3);
    }

    #[test(creator = @owner, admin = @admin)]
    #[expected_failure(abort_code = erc20::E_NOT_ADMIN , location = erc20)]
    fun test_set_pause_failed_when_not_admin(creator: &signer, admin: &signer) {
        erc20::initialize(creator);
        erc20::set_admin(admin, @user);
        erc20::set_pause(admin, true);
    }

    #[test(creator = @owner, user = @user)]
    fun test_create_toke_success(creator: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir",
            b"deUSD",
            8,
            b"",
            b""
        );
        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        assert!(token_address == object::create_object_address(&signer::address_of(user), b"deUSD"), 4);
    }

    #[test(creator = @owner, user1 = @0x101, user2 = @0x102)]
    fun test_multi_user_create_same_token_success(creator: &signer, user1: &signer, user2: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user1,
            option::none(),
            b"Elixir deUSD",
            b"deUSD",
            8,
            b"",
            b""
        );
        erc20::create_token(
            user2,
            option::none(),
            b"Elixir deUSD",
            b"deUSD",
            8,
            b"",
            b""
        );
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_PAUSED, location = erc20)]
    fun test_create_token_failed_when_paused(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::set_pause(admin, true);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"deUSD",
            8,
            b"",
            b""
        );
    }

    #[test(creator = @owner, user = @user)]
    #[expected_failure(abort_code = erc20::E_TOKEN_ALREADY_EXISTS, location = erc20)]
    fun test_create_token_failed_when_already_exists_token(creator: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir",
            b"deUSD",
            8,
            b"",
            b""
        );
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"deUSD",
            8,
            b"",
            b""
        );
    }

    #[test(creator = @owner, admin =@admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_PAUSED_CREATOR_TOKEN, location = erc20)]
    fun test_create_token_failed_when_paused_creator_token(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir",
            b"deUSD",
            8,
            b"",
            b""
        );
        assert!(!erc20::is_creator_token_paused(@user), 5);
        erc20::set_pause_creator_token(admin, @user, true);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_PAUSED, location = erc20)]
    fun test_mint_failed_when_paused(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::set_pause(admin, true);
        erc20::mint(user, token_address, @user, 100);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_ACCOUNT_HAS_NO_TOKENS, location = erc20)]
    fun test_mint_failed_when_account_has_no_tokens(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(admin, token_address, @user, 100);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_PAUSED_CREATOR_TOKEN, location = erc20)]
    fun test_mint_failed_when_paused_creator_token(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::set_pause_creator_token(admin, @user, true);
        erc20::mint(user, token_address, @user, 100);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_ACCOUNT_NOT_OWNED_TOKEN, location = erc20)]
    fun test_mint_failed_when_not_owned_token(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            admin,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(admin, token_address, @user, 100);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    fun test_mint_success(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        erc20::set_pause_creator_token(admin, @user, true);
        erc20::set_pause_creator_token(admin, @user, false);

        let (token_address, token_metadata) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);
        assert!(primary_fungible_store::balance(@user, token_metadata) == 100, 6);
        erc20::mint(user, token_address, @admin, 200);
        assert!(primary_fungible_store::balance(@admin, token_metadata) == 200, 7);
        assert!(erc20::get_total_supply(token_address) == 300, 8);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_PAUSED, location = erc20)]
    fun test_burn_failed_when_paused(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);

        erc20::set_pause(admin, true);
        erc20::burn(user, token_address, @user, 100);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_ACCOUNT_HAS_NO_TOKENS, location = erc20)]
    fun test_burn_failed_when_account_has_no_tokens(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);
        erc20::burn(admin, token_address, @user, 10);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_PAUSED_CREATOR_TOKEN, location = erc20)]
    fun test_burn_failed_when_paused_creator_token(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);

        erc20::set_pause_creator_token(admin, @user, true);
        erc20::burn(user, token_address, @user, 10);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_ACCOUNT_NOT_OWNED_TOKEN, location = erc20)]
    fun test_burn_failed_when_not_owned_token(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            admin,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);
        erc20::burn(admin, token_address, @user, 10);
    }

    #[test(creator = @owner, user = @user)]
    #[expected_failure(abort_code = erc20::E_NOT_ENOUGH_BALANCE_TO_BURN, location = erc20)]
    fun test_burn_failed_when_not_enough_balance(creator: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);
        erc20::mint(user, token_address, @admin, 200);

        erc20::burn(user, token_address, @user, 150);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    fun test_burn_success(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        erc20::set_pause_creator_token(admin, @user, true);
        erc20::set_pause_creator_token(admin, @user, false);

        let (token_address, token_metadata) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);
        erc20::mint(user, token_address, @admin, 200);

        erc20::burn(user, token_address, @user, 50);
        erc20::burn(user, token_address, @admin, 50);
        assert!(primary_fungible_store::balance(@user, token_metadata) == 50, 9);
        assert!(primary_fungible_store::balance(@admin, token_metadata) == 150, 10);
        assert!(erc20::get_total_supply(token_address) == 200, 11);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_PAUSED, location = erc20)]
    fun test_transfer_failed_when_paused(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @admin, 100);

        erc20::set_pause(admin, true);
        erc20::transfer(admin, token_address, @user, 20);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    #[expected_failure(abort_code = erc20::E_NOT_ENOUGH_BALANCE_TO_TRANSFER, location = erc20)]
    fun test_transfer_failed_when_not_enough_balance(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, _) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @admin, 200);

        erc20::transfer(admin, token_address, @user, 250);
    }

    #[test(creator = @owner, admin = @admin, user = @user)]
    fun test_transfer_success(creator: &signer, admin: &signer, user: &signer) {
        erc20::initialize(creator);
        erc20::create_token(
            user,
            option::none(),
            b"Elixir deUSD",
            b"USD",
            8,
            b"",
            b""
        );

        let (token_address, token_metadata) = erc20::get_new_token_address_and_metadata();
        erc20::mint(user, token_address, @user, 100);
        erc20::mint(user, token_address, @admin, 200);

        erc20::transfer(user, token_address, @0x123, 50);
        erc20::transfer(admin, token_address, @0x123, 100);
        assert!(primary_fungible_store::balance(@user, token_metadata) == 50, 12);
        assert!(primary_fungible_store::balance(@admin, token_metadata) == 100, 13);
        assert!(primary_fungible_store::balance(@0x123, token_metadata) == 150, 14);
        assert!(erc20::get_total_supply(token_address) == 300, 15);
    }
}
