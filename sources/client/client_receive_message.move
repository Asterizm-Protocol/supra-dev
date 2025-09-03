module asterizm::client_receive_message {
    use std::signer;
    use std::hash;
    use aptos_std::simple_map;
    use aptos_std::event;

    use asterizm::client_client;
    use asterizm::client_settings;
    use asterizm::relayer_chain;
    use asterizm::client_serialize;

    friend asterizm::initializer_receive_message;
    
    const E_NOT_INITIALIZED: u64 = 0;
    const E_UNAUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INVALID_HASH: u64 = 3;
    const E_TRANSFER_EXISTS: u64 = 4;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;
    
    // Events
    #[event]
    struct PayloadReceivedEvent has drop, store {
        src_chain_id: u64,
        src_address: address,
        tx_id: u128,
        transfer_hash: vector<u8>,
    }

    #[event]
    struct TransferSendingResultEvent has drop, store {
        dst_address: address,
        transfer_hash: vector<u8>,
        status_code: u8
    }

    public(friend) fun init_receive_message(
        dst_address: address,
        src_address: address,
        src_chain_id: u64,
        tx_id: u128,
        transfer_hash: vector<u8>,
    ) {
        let (_, trusted_addresses, _) = client_client::get_client_info(dst_address);

        let trusted_address = *simple_map::borrow(&trusted_addresses, &src_chain_id);

        assert!(trusted_address == src_address, E_UNAUTHORIZED);

        client_client::add_incoming_transfer(dst_address, transfer_hash);

        event::emit(
            PayloadReceivedEvent {
                src_chain_id,
                src_address,
                tx_id,
                transfer_hash,
            }
        );
    }

    public entry fun receive_message(
        sender: &signer,
        dst_address: address,
        tx_id: u128,
        src_chain_id: u64,
        src_address: address,
        transfer_hash: vector<u8>,
        payload: vector<u8>,
    ) {
        let sender_addr = signer::address_of(sender);

        client_client::check_sender_exist(dst_address, sender_addr);

        client_client::check_incoming_transfer_not_executed(dst_address, transfer_hash);

        let local_chain_id = client_settings::get_local_chain_id();

        let client_disable_hash_validation = client_client::get_client_disable_hash_validation(dst_address);

        let buffer = client_serialize::serialize_message(
            src_chain_id,
            src_address,
            local_chain_id,
            dst_address,
            tx_id,
            payload
        );

        let chain_type = relayer_chain::get_chain_type(src_chain_id);

        let calculated_transfer_hash = if (chain_type == 1 || chain_type == 4)
        {
            hash::sha2_256(buffer)
        } else {
            client_serialize::build_crosschain_hash(buffer)
        };

        if (!client_disable_hash_validation)
        {
            assert!(transfer_hash == calculated_transfer_hash, E_INVALID_HASH);
        };

        client_client::set_incoming_transfer_success(dst_address, transfer_hash);
    }

    public(friend) fun transfer_sending_result(
        dst_address: address,
        transfer_hash: vector<u8>,
        status_code: u8
    ) {
        let (_, _, _) = client_client::get_client_info(dst_address);

        event::emit(
            TransferSendingResultEvent {
                dst_address,
                transfer_hash,
                status_code,
            }
        );
    }
}
