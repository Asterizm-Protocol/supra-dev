module asterizm::client_send_message {
    use std::signer;
    use std::hash;
    use aptos_std::simple_map;
    use aptos_std::event;

    use asterizm::client_client;
    use asterizm::client_settings;
    use asterizm::client_serialize;
    use asterizm::relayer_chain;
    use asterizm::initializer_send_message;
    
    const E_NOT_INITIALIZED: u64 = 0;
    const E_UNAUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INVALID_HASH: u64 = 3;
    const E_TRANSFER_EXISTS: u64 = 4;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;
    
    // Events
    #[event]
    struct InitiateTransferEvent has drop, store {
        dst_chain_id: u64,
        trusted_address: address,
        tx_id: u128,
        transfer_hash: vector<u8>,
        payload: vector<u8>,
    }

    public entry fun init_send_message(
        _sender: &signer,
        user_address: address,
        dst_chain_id: u64,
        payload: vector<u8>
    ) {
        let (tx_id, trusted_addresses, _senders) = client_client::get_client_info(user_address);
        let local_chain_id = client_settings::get_local_chain_id();
        
        let trusted_address = *simple_map::borrow(&trusted_addresses, &dst_chain_id);

        client_client::increment_client_tx_id(user_address);
        
        let buffer = client_serialize::serialize_message(
            local_chain_id,
            user_address,
            dst_chain_id,
            trusted_address,
            tx_id,
            payload
        );

        let chain_type = relayer_chain::get_chain_type(dst_chain_id);

        let transfer_hash = if (chain_type == 1 || chain_type == 4)
        {
            hash::sha2_256(buffer)
        } else {
            client_serialize::build_crosschain_hash(buffer)
        };
        
        client_client::add_outgoing_transfer(user_address, transfer_hash);

        event::emit(
            InitiateTransferEvent {
                dst_chain_id,
                trusted_address,
                tx_id,
                transfer_hash,
                payload,
            }
        );
    }
    
    public entry fun send_message(
        sender: &signer,
        user_address: address,
        dst_chain_id: u64,
        tx_id: u128,
        transfer_hash: vector<u8>,
        value: u64,
    ) {

        let sender_addr = signer::address_of(sender);

        client_client::check_sender_exist(user_address, sender_addr);

        let (relay_owner, trusted_address, notify_transfer_sending_result) = client_client::get_sender_client_info(user_address, dst_chain_id);
        
        client_client::check_outgoing_transfer(user_address, transfer_hash);

        initializer_send_message::send_message(
            sender,
            relay_owner,
            dst_chain_id,
            user_address,
            trusted_address,
            tx_id,
            notify_transfer_sending_result,
            transfer_hash,
            value,
        );

        client_client::set_outgoing_transfer_success(user_address, transfer_hash);
    }
    
    public entry fun resend_message(
        sender: &signer,
        user_address: address,
        transfer_hash: vector<u8>,
        value: u64,
    ) {
        let sender_addr = signer::address_of(sender);

        client_client::check_sender_exist(user_address, sender_addr);

        let relay_owner = client_client::get_client_relay_owner(user_address);
        
        client_client::check_outgoing_transfer_success(user_address, transfer_hash);

        initializer_send_message::resend_message(
            sender,
            relay_owner,
            user_address,
            transfer_hash,
            value,
        );
    }
}
