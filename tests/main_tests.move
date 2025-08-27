#[test_only]
module asterizm::main_tests {
    use std::signer;
    use std::vector;
    use std::string;
    use std::hash;

    use aptos_std::simple_map;

    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;
    
    use asterizm::initializer_settings;
    use asterizm::relayer_settings;
    use asterizm::relayer_chain;
    use asterizm::relayer_receive_message;
    use asterizm::client_client;
    use asterizm::client_send_message;
    use asterizm::client_receive_message;
    use asterizm::client_settings;
    use asterizm::client_serialize;

    const TEST_CHAIN_ID: u64 = 123;
    const TEST_LOCAL_CHAIN_ID: u64 = 321;
    const TEST_FEE: u64 = 100;
    const TEST_RELAY_OWNER: address = @0x123;
    const TEST_RELAY_OWNER2: address = @0x124;
    const TEST_USER: address = @0x456;
    const TEST_SENDER: address = @0x789;


    // Helper functions
    #[test_only]
    fun setup_asterizm_admin() {
        account::create_account_for_test(@asterizm);
    }

    #[test_only]
    fun setup_user(user: &signer){
       let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
    }

    #[test_only]
    fun setup_client(
        user: &signer,
        ) {
        setup_user(user);
        client_client::create_client(user, TEST_RELAY_OWNER, true, false, true);
        client_client::create_trusted_address(user, TEST_CHAIN_ID, TEST_USER);
        client_client::create_sender(user, TEST_SENDER);
    }

    #[test_only]
    fun mint_supra_coin(supra_framework: &signer, sender: &signer, relay_owner: &signer, balance: u64) {
        use supra_framework::coin;
        use supra_framework::supra_coin::{Self, SupraCoin};

        let sender_addr = signer::address_of(sender);
        let relay_owner_addr = signer::address_of(relay_owner);

        account::create_account_for_test(sender_addr);
        account::create_account_for_test(relay_owner_addr);
        account::create_account_for_test(@supra_framework);

        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(supra_framework);

        coin::register<SupraCoin>(sender);
        coin::register<SupraCoin>(relay_owner);
        coin::create_pairing<SupraCoin>(supra_framework);
        supra_coin::mint(supra_framework, sender_addr, balance);
        supra_coin::mint(supra_framework, relay_owner_addr, balance);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // Relayer Settings Tests
    #[test(admin = @asterizm)]
    fun test_relayer_settings_flow(
        admin: signer,
        ) {
        setup_asterizm_admin();
        
        // Initialize relayer settings
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_CHAIN_ID, TEST_FEE);
        assert!(relayer_settings::get_system_relayer_owner() == TEST_RELAY_OWNER, 200);
        assert!(relayer_settings::get_system_fee() == TEST_FEE, 201);

        // Update settings
        let new_fee = 200;
        relayer_settings::update_settings(&admin, new_fee);
        assert!(relayer_settings::get_system_fee() == new_fee, 202);
    }

    // Relayer Settings Tests
    #[test(admin = @asterizm, unauthorized = @0x456)]
    #[expected_failure(abort_code = 303)] // ERR_UNREACHABLE
    fun test_relayer_settings_negative_case(
        admin: signer,
        unauthorized: signer,
        ) {
        setup_asterizm_admin();
        setup_user(&unauthorized);
        
        // Initialize relayer settings
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_CHAIN_ID, TEST_FEE);
        assert!(relayer_settings::get_system_relayer_owner() == TEST_RELAY_OWNER, 200);
        assert!(relayer_settings::get_system_fee() == TEST_FEE, 201);

        // Update settings
        let new_fee = 200;
        relayer_settings::update_settings(&unauthorized, new_fee);
    }

    // Custom Relayer Tests
    #[test(admin = @asterizm)]
    fun test_custom_relayer_flow(
        admin: signer,
    ) {
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_CHAIN_ID, TEST_FEE);

        // Create custom relayer
        relayer_settings::create_custom_relay(&admin, TEST_RELAY_OWNER2, TEST_FEE);
        assert!(relayer_settings::get_relay_fee(TEST_RELAY_OWNER2) == TEST_FEE, 300);

        // Update custom relayer
        let new_fee = 150;
        relayer_settings::update_custom_relay(&admin, TEST_RELAY_OWNER2, new_fee);
        assert!(relayer_settings::get_relay_fee(TEST_RELAY_OWNER2) == new_fee, 301);
    }

    // Custom Relayer Negative
    #[test(admin = @asterizm)]
    #[expected_failure(abort_code = 304)] // ERR_NOT_RELAY_OWNER
    fun test_custom_relayer_negative_case(
        admin: signer,
    ) {
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_CHAIN_ID, TEST_FEE);
      
        // Create custom relayer
        relayer_settings::create_custom_relay(&admin, TEST_RELAY_OWNER2, TEST_FEE);

        // Get relayer fee for unknown relay owner
        let _ = relayer_settings::get_relay_fee(TEST_USER);
    }

    // Relayer chain Tests
    #[test(admin = @asterizm)]
    fun test_relayer_chain_flow(
        admin: signer,
    ) {
        setup_asterizm_admin();

        // Create custom relayer
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 1);
        assert!(relayer_chain::get_chain_type(TEST_CHAIN_ID) == 1, 300);

        // Update custom relayer
        let new_chain_type = 2;
        relayer_chain::update_chain_type(&admin, TEST_CHAIN_ID, new_chain_type);
        assert!(relayer_chain::get_chain_type(TEST_CHAIN_ID) == new_chain_type, 301);
    }

    // Relayer chain Negative
    #[test(admin = @asterizm, unauthorized = @0x456)]
    #[expected_failure(abort_code = 303)] // ERR_UNREACHABLE
    fun test_relayer_chain_negative_case(
        admin: signer,
        unauthorized: signer,
    ) {
        setup_asterizm_admin();
        setup_user(&unauthorized);
        // Create custom relayer
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 1);

        // Update custom relayer
        let new_chain_type = 2;
        relayer_chain::update_chain_type(&unauthorized, TEST_CHAIN_ID, new_chain_type);
    }

    // Initializer Positive Tests
    #[test(admin = @asterizm, user = @0x456)]
    fun test_initializer_flow(
        admin: signer,
        user: signer,
    ) {
        setup_asterizm_admin();
        setup_user(&user);

        // Test initialization
        initializer_settings::initialize(&admin, TEST_CHAIN_ID);
        assert!(initializer_settings::get_local_chain_id() == TEST_CHAIN_ID, 100);

        // Test account blocking
        initializer_settings::block_account(&admin, TEST_CHAIN_ID, TEST_USER);
        assert!(initializer_settings::check_address_is_blocked(TEST_USER), 101);

        // Test account unblocking
        initializer_settings::unblock_account(&admin, TEST_USER);
        assert!(!initializer_settings::check_address_is_blocked(TEST_USER), 102);
    }

    // Initializer Negative Tests
    #[test(admin = @asterizm, user = @0x456)]
    #[expected_failure(abort_code = 303)] // ERR_UNREACHABLE
    fun test_initializer_block_negative_case(
        admin: signer,
        user: signer,
    ) {
        setup_asterizm_admin();
        setup_user(&user);

        // Test initialization
        initializer_settings::initialize(&admin, TEST_CHAIN_ID);
        assert!(initializer_settings::get_local_chain_id() == TEST_CHAIN_ID, 100);

        // Test unauthorized access
        initializer_settings::block_account(&user, TEST_CHAIN_ID, TEST_USER);
    }

    // Initializer Negative Tests
    #[test(admin = @asterizm, user = @0x456)]
    #[expected_failure(abort_code = 303)] // ERR_UNREACHABLE
    fun test_initializer_unblock_negative_case(
        admin: signer,
        user: signer,
    ) {
        setup_asterizm_admin();
        setup_user(&user);

        // Test initialization
        initializer_settings::initialize(&admin, TEST_CHAIN_ID);
        assert!(initializer_settings::get_local_chain_id() == TEST_CHAIN_ID, 100);

        // Test account blocking
        initializer_settings::block_account(&admin, TEST_CHAIN_ID, TEST_USER);
        assert!(initializer_settings::check_address_is_blocked(TEST_USER), 101);

        // Test unauthorized access
        initializer_settings::unblock_account(&user, TEST_USER);
    }

    // Client Settings Tests
    #[test(admin = @asterizm)]
    fun test_client_settings_flow(
        admin: signer,
        ) {
        setup_asterizm_admin();

        client_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        assert!(client_settings::get_local_chain_id() == TEST_LOCAL_CHAIN_ID, 401);
    }

    // Client Management Tests
    #[test( user = @0x456)]
    fun test_client_management(
        user: signer,
        ) {
        setup_user(&user);
        
        // Create client
        client_client::create_client(&user, TEST_RELAY_OWNER, true, false, true);
        let (tx_id, trusted, senders) = client_client::get_client_info(TEST_USER);
        assert!(tx_id == 0, 400);
        assert!(simple_map::length(&trusted) == 0, 401);
        assert!(vector::length(&senders) == 0, 402);

        // Add trusted address
        client_client::create_trusted_address(&user, TEST_CHAIN_ID, TEST_RELAY_OWNER);
        let (_, trusted, _) = client_client::get_client_info(TEST_USER);
        assert!(simple_map::length(&trusted) == 1, 403);

        // Add sender
        client_client::create_sender(&user, TEST_SENDER);
        let (_, _, senders) = client_client::get_client_info(TEST_USER);
        assert!(vector::length(&senders) == 1, 404);

        // Remove sender
        client_client::delete_sender(&user, TEST_SENDER);
        let (_, _, senders) = client_client::get_client_info(TEST_USER);
        assert!(vector::length(&senders) == 0, 405);
    }

    // Message Flow Tests
    #[test(supra_framework = @supra_framework, admin = @asterizm, user = @0x456, relayer = @0x123, sender = @0x789)]
    fun test_message_send_flow(
        supra_framework: signer,
        admin: signer,
        user: signer,
        relayer: signer,
        sender: signer,
        ) {
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_LOCAL_CHAIN_ID, TEST_FEE);
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 2);
        initializer_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        client_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        setup_client(&user);
        mint_supra_coin(&supra_framework, &sender, &relayer, 10000);

        // Test message initiation
        let payload = b"test_payload";
        let src_chain_id = TEST_LOCAL_CHAIN_ID;
        let dst_chain_id = TEST_CHAIN_ID;
        let src_address = TEST_USER;
        let dst_address = TEST_USER;
        let tx_id = 0;

        let buffer = client_serialize::serialize_message(
            src_chain_id,
            src_address,
            dst_chain_id,
            dst_address,
            tx_id,
            payload
        );

        let transfer_hash = client_serialize::build_crosschain_hash(buffer);

        client_send_message::init_send_message(
            &sender, 
            dst_address, 
            dst_chain_id, 
            payload
        );

        // Test message sending
        client_send_message::send_message(
            &sender,
            dst_address,
            dst_chain_id,
            tx_id,
            transfer_hash,
            TEST_FEE
        );

        let (new_tx_id, _, _) = client_client::get_client_info(TEST_USER);
        assert!(new_tx_id == 1, 500);
    }

    // Message Flow Tests
    #[test(admin = @asterizm, user = @0x456, relayer = @0x123, sender = @0x789)]
    fun test_message_receive_flow(
        admin: signer,
        user: signer,
        relayer: signer,
        sender: signer,
        ) {
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_LOCAL_CHAIN_ID, TEST_FEE);
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 2);
        initializer_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        client_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        setup_client(&user);

        // Test message initiation
        let src_chain_id = TEST_CHAIN_ID;
        let local_chain_id = TEST_LOCAL_CHAIN_ID;
        let dst_address = TEST_USER;
        let src_address = TEST_USER;
        let tx_id = 1;

        let payload = b"test_payload";
        let buffer = client_serialize::serialize_message(
            src_chain_id,
            src_address,
            local_chain_id,
            dst_address,
            tx_id,
            payload
        );

        let transfer_hash = client_serialize::build_crosschain_hash(buffer);

        relayer_receive_message::transfer_message(
            &relayer, 
            src_chain_id, 
            src_address,
            TEST_USER,
            1,
            transfer_hash
        );

        // Test message receiving
        client_receive_message::receive_message(
            &sender,
            TEST_USER,
            1,
            src_chain_id,
            src_address,
            transfer_hash,
            payload
        );
    }

    // Failure Case Tests
    #[test(supra_framework = @supra_framework, admin = @asterizm, user = @0x456, relayer = @0x123, sender = @0x789)]
    #[expected_failure(abort_code = 500)] // ERR_BLOCKED_ACCOUNT
    fun test_blocked_account_send(
        supra_framework: signer,
        admin: signer,
        user: signer,
        relayer: signer,
        sender: signer,
        ) {
        
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_LOCAL_CHAIN_ID, TEST_FEE);
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 2);
        initializer_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        client_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        setup_client(&user);
        mint_supra_coin(&supra_framework, &sender, &relayer, 10000);

        initializer_settings::block_account(&admin, TEST_LOCAL_CHAIN_ID, TEST_USER);

        // Test message initiation
        let payload = b"test_payload";
        let src_chain_id = TEST_LOCAL_CHAIN_ID;
        let dst_chain_id = TEST_CHAIN_ID;
        let src_address = TEST_USER;
        let dst_address = TEST_USER;
        let tx_id = 0;

        let buffer = client_serialize::serialize_message(
            src_chain_id,
            src_address,
            dst_chain_id,
            dst_address,
            tx_id,
            payload
        );

        let transfer_hash = client_serialize::build_crosschain_hash(buffer);

        client_send_message::init_send_message(
            &sender, 
            dst_address, 
            dst_chain_id, 
            payload
        );

        // Test message to blocked account
        client_send_message::send_message(
            &sender,
            dst_address,
            dst_chain_id,
            tx_id,
            transfer_hash,
            TEST_FEE
        );
    }

    #[test(supra_framework = @supra_framework, admin = @asterizm, user = @0x456, relayer = @0x123, sender = @0x789)]
    #[expected_failure(abort_code = 302)] // ERR_INVALID_FEE
    fun test_insufficient_fee(
        supra_framework: signer,
        admin: signer,
        user: signer,
        relayer: signer,
        sender: signer,
        ) {

        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_LOCAL_CHAIN_ID, TEST_FEE);
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 2);
        initializer_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        client_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        setup_client(&user);
        mint_supra_coin(&supra_framework, &sender, &relayer, 10000);

        // Test message initiation
        let payload = b"test_payload";
        let src_chain_id = TEST_LOCAL_CHAIN_ID;
        let dst_chain_id = TEST_CHAIN_ID;
        let src_address = TEST_USER;
        let dst_address = TEST_USER;
        let tx_id = 0;

        let buffer = client_serialize::serialize_message(
            src_chain_id,
            src_address,
            dst_chain_id,
            dst_address,
            tx_id,
            payload
        );

        let transfer_hash = client_serialize::build_crosschain_hash(buffer);

        client_send_message::init_send_message(
            &sender, 
            dst_address, 
            dst_chain_id, 
            payload
        );

        // Test message with insufficient fee
        client_send_message::send_message(
            &sender,
            dst_address,
            dst_chain_id,
            tx_id,
            transfer_hash,
            TEST_FEE - 10
        );
        
    }

    #[test(supra_framework = @supra_framework, admin = @asterizm, user = @0x456, relayer = @0x123, sender = @0x789)]
    fun test_resend_message_flow(
        supra_framework: signer,
        admin: signer,
        user: signer,
        relayer: signer,
        sender: signer,
    ) {
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_LOCAL_CHAIN_ID, TEST_FEE);
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 2);
        initializer_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        client_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        setup_client(&user);
        mint_supra_coin(&supra_framework, &sender, &relayer, 10000);

        // Send initial message
        let payload = b"test_payload";
        client_send_message::init_send_message(&sender, TEST_USER, TEST_CHAIN_ID, payload);

        let (tx_id, _, _) = client_client::get_client_info(TEST_USER);
        let buffer = client_serialize::serialize_message(
            TEST_LOCAL_CHAIN_ID,
            TEST_USER,
            TEST_CHAIN_ID,
            TEST_USER,
            tx_id - 1,
            payload
        );
        let transfer_hash = client_serialize::build_crosschain_hash(buffer);

        client_send_message::send_message(
            &sender,
            TEST_USER,
            TEST_CHAIN_ID,
            tx_id - 1,
            transfer_hash,
            TEST_FEE
        );

        // Resend message
        client_send_message::resend_message(
            &sender,
            TEST_USER,
            TEST_CHAIN_ID,
            transfer_hash,
            TEST_FEE
        );

        // Verify fee is deducted twice
        let relay_balance = coin::balance<SupraCoin>(TEST_RELAY_OWNER);
        assert!(relay_balance == 10000 + TEST_FEE * 2, 800);
    }

    #[test]
    fun test_large_payload_hash() {
        let large_payload = vector::empty();
        let i = 0;
        while (i < 150) {
            vector::push_back(&mut large_payload, i);
            i = i + 1;
        };
        let buffer = client_serialize::serialize_message(1, @0x1, 2, @0x2, 0, large_payload);
        let hash = client_serialize::build_crosschain_hash(buffer);
        assert!(vector::length(&hash) == 32, 900);
    }

    #[test(admin = @asterizm, user = @0x456, relayer = @0x123, sender = @0x789)]
    fun test_receive_message_chain_type_1(
        admin: signer,
        user: signer,
        relayer: signer,
        sender: signer,
    ) {
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_LOCAL_CHAIN_ID, TEST_FEE);
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 1);
        initializer_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        client_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        setup_client(&user);

        let src_chain_id = TEST_CHAIN_ID;
        let local_chain_id = TEST_LOCAL_CHAIN_ID;
        let payload = b"test_payload";
        let buffer = client_serialize::serialize_message(
            src_chain_id,
            TEST_USER,
            local_chain_id,
            TEST_USER,
            1,
            payload
        );
        let transfer_hash = hash::sha2_256(buffer);

        relayer_receive_message::transfer_message(
            &relayer, 
            src_chain_id, 
            TEST_USER,
            TEST_USER,
            1,
            transfer_hash
        );

        client_receive_message::receive_message(
            &sender,
            TEST_USER,
            1,
            src_chain_id,
            TEST_USER,
            transfer_hash,
            payload
        );
    }

    #[test(admin = @asterizm, relayer = @0x123)]
    #[expected_failure(abort_code = 500)]
    fun test_blocked_dst_address_receive(
        admin: signer,
        relayer: signer,
    ) {
        setup_asterizm_admin();
        relayer_settings::initialize(&admin, TEST_RELAY_OWNER, TEST_LOCAL_CHAIN_ID, TEST_FEE);
        relayer_chain::create_chain(&admin, TEST_CHAIN_ID, string::utf8(b"Eth"), 2);
        initializer_settings::initialize(&admin, TEST_LOCAL_CHAIN_ID);
        // Block destination address
        initializer_settings::block_account(&admin, TEST_LOCAL_CHAIN_ID, TEST_USER);
        
        relayer_receive_message::transfer_message(
            &relayer, 
            TEST_CHAIN_ID, 
            @0x999,
            TEST_USER,
            1,
            vector::empty()
        );
    }

    #[test(user = @0x456)]
    fun test_delete_trusted_address(user: signer) {
        setup_user(&user);
        client_client::create_client(&user, TEST_RELAY_OWNER, true, false, true);
        
        client_client::create_trusted_address(&user, TEST_CHAIN_ID, TEST_RELAY_OWNER);
        client_client::delete_trusted_address(&user, TEST_CHAIN_ID);
        
        let (_, trusted, _) = client_client::get_client_info(TEST_USER);

        assert!(!simple_map::contains_key(&trusted, &TEST_CHAIN_ID), 920);
    }

}
