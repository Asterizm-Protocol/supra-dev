module asterizm::client_client {
    use std::signer;
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::event;
    use aptos_std::table::{Self, Table};

    friend asterizm::client_receive_message;
    friend asterizm::client_send_message;

    const E_NOT_INITIALIZED: u64 = 0;
    const E_UNAUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INVALID_HASH: u64 = 3;
    const E_TRANSFER_EXISTS: u64 = 4;
    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;
    
    struct Client has key {
        user_address: address,
        relay_owner: address,
        notify_transfer_sending: bool,
        disable_hash_validation: bool,
        refund_enabled: bool,
        tx_id: u128,
        trusted_addresses: SimpleMap<u64, address>,
        senders: vector<address>,
    }   

    struct OutgoingTransfers has key {
        data: Table<vector<u8>, OutgoingTransfer>,
    }

    struct IncomingTransfers has key {
        data: Table<vector<u8>, IncomingTransfer>,
    }

    struct RefundAccounts has key {
        data: Table<vector<u8>, RefundAccount>,
    }

    struct OutgoingTransfer has store {
        success_execute: bool,
        refunded: bool,
    }

    struct IncomingTransfer has store {
        success_receive: bool,
        success_execute: bool,
    }

    struct RefundAccount has store {
        status: u8,
    }

    // Events
    #[event]
    struct ClientCreatedEvent has drop, store {
        user_address: address,
        relay_owner: address,
        notify_transfer_sending: bool,
        disable_hash_validation: bool,
    }

    #[event]
    struct AddRefundRequestEvent has drop, store {
        user_address: address,
        transfer_hash: vector<u8>
    }

    // Client management
    public entry fun create_client(
        user: &signer,
        relay_owner: address,
        notify_transfer_sending_result: bool,
        disable_hash_validation: bool,
        refund_enabled: bool
    ) {
        let user_addr = signer::address_of(user);
        assert!(!exists<Client>(user_addr), E_ALREADY_INITIALIZED);

        move_to(user, Client {
            user_address: user_addr,
            relay_owner,
            notify_transfer_sending: notify_transfer_sending_result,
            disable_hash_validation,
            refund_enabled,
            tx_id: 0,
            trusted_addresses: simple_map::create(),
            senders: vector[],
        });

        move_to(user, OutgoingTransfers {
            data: table::new<vector<u8>, OutgoingTransfer>(),
        });

        move_to(user, IncomingTransfers {
            data: table::new<vector<u8>, IncomingTransfer>(),
        });

        move_to(user, RefundAccounts {
            data: table::new<vector<u8>, RefundAccount>(),
        });

        event::emit(
            ClientCreatedEvent {
                user_address: user_addr,
                relay_owner,
                notify_transfer_sending: notify_transfer_sending_result,
                disable_hash_validation,
            }
        );
    }

    public entry fun create_client_refund_accounts(
        user: &signer,
    ) {
        let user_addr = signer::address_of(user);

        move_to(user, RefundAccounts {
            data: table::new<vector<u8>, RefundAccount>(),
        });
    }

    public entry fun create_trusted_address(
        user: &signer,
        chain_id: u64,
        trusted_address: address
    ) acquires Client {
        let user_addr = signer::address_of(user);
        let client = borrow_global_mut<Client>(user_addr);

        assert!(client.user_address == user_addr, E_UNAUTHORIZED);

        simple_map::add(&mut client.trusted_addresses, chain_id, trusted_address);
    }

    public entry fun delete_trusted_address(
        user: &signer,
        chain_id: u64,
    ) acquires Client {
        let user_addr = signer::address_of(user);
        let client = borrow_global_mut<Client>(user_addr);

        assert!(client.user_address == user_addr, E_UNAUTHORIZED);

        simple_map::remove(&mut client.trusted_addresses, &chain_id);
    }

    public entry fun create_sender(
        user: &signer,
        sender: address
    ) acquires Client {
        let user_addr = signer::address_of(user);
        let client = borrow_global_mut<Client>(user_addr);

        assert!(client.user_address == user_addr, E_UNAUTHORIZED);

        vector::push_back(&mut client.senders, sender);
    }

    public entry fun delete_sender(
        user: &signer,
        sender: address
    ) acquires Client {
        let user_addr = signer::address_of(user);
        let client = borrow_global_mut<Client>(user_addr);

        assert!(client.user_address == user_addr, E_UNAUTHORIZED);

        let (found, index) = vector::index_of(&client.senders, &sender);
        if (found) {
            vector::remove(&mut client.senders, index);
        }
    }

    #[view]
    public fun get_client_info(
        client: address
    ): (
        u128,
        SimpleMap<u64, address>,
        vector<address>,
    ) acquires Client {
        let client = borrow_global<Client>(client);
        (client.tx_id, client.trusted_addresses, client.senders)
    }


    #[view]
    public fun get_sender_client_info(
        client: address,
        dst_chain_id: u64
    ): (
        address,
        address,
        bool
    ) acquires Client {
        assert!(exists<Client>(client), E_NOT_INITIALIZED);

        let client = borrow_global<Client>(client);

        let trusted_address = *simple_map::borrow(&client.trusted_addresses, &dst_chain_id);

        (client.relay_owner, trusted_address, client.notify_transfer_sending)
    }

    #[view]
    public fun get_client_disable_hash_validation(
        client: address,
    ): bool acquires Client {
        assert!(exists<Client>(client), E_NOT_INITIALIZED);

        let client = borrow_global<Client>(client);

        client.disable_hash_validation
    }

    public fun check_sender_exist(
        client_address: address,
        sender: address,
    ) acquires Client {
        assert!(exists<Client>(client_address), E_NOT_INITIALIZED);

        let client = borrow_global<Client>(client_address);

        let (found, _) = vector::index_of(&client.senders, &sender);

        assert!(found, E_UNAUTHORIZED);
    }

    public fun increment_client_tx_id(
        client_address: address,
    ) acquires Client {
        let client = borrow_global_mut<Client>(client_address);
        client.tx_id = client.tx_id + 1;
    }

    public(friend) fun add_outgoing_transfer(
        user: address,
        transfer_hash: vector<u8>
    ) acquires OutgoingTransfers {
        let client = borrow_global_mut<OutgoingTransfers>(user);
        table::add(&mut client.data, transfer_hash, OutgoingTransfer {
            success_execute: false,
            refunded: false,
        });
    }

    public(friend) fun set_outgoing_transfer_success(
        user: address,
        transfer_hash: vector<u8>
    ) acquires OutgoingTransfers {
        let client = borrow_global_mut<OutgoingTransfers>(user);
        let transfer = table::borrow_mut(&mut client.data, transfer_hash);
        transfer.success_execute = true;
    }

    public fun check_outgoing_transfer_success(
        user: address,
        transfer_hash: vector<u8>
    ) acquires OutgoingTransfers {
        let client = borrow_global<OutgoingTransfers>(user);
        let transfer = table::borrow(&client.data, transfer_hash);
        assert!(transfer.success_execute && !transfer.refunded, E_UNAUTHORIZED);
    }

    public fun check_outgoing_transfer(
        user: address,
        transfer_hash: vector<u8>
    ) acquires OutgoingTransfers {
        let client = borrow_global<OutgoingTransfers>(user);
        let transfer = table::borrow(&client.data, transfer_hash);
        assert!(!transfer.success_execute && !transfer.refunded, E_UNAUTHORIZED);
    }

     public(friend) fun add_incoming_transfer(
        user: address,
        transfer_hash: vector<u8>
    ) acquires IncomingTransfers {
        let client = borrow_global_mut<IncomingTransfers>(user);
        table::add(&mut client.data, transfer_hash, IncomingTransfer {
            success_receive: true,
            success_execute: false,
        });
    }

    public fun check_incoming_transfer_not_executed(
        user: address,
        transfer_hash: vector<u8>
    ) acquires IncomingTransfers {
        let client = borrow_global<IncomingTransfers>(user);
        let transfer = table::borrow(&client.data, transfer_hash);
        assert!(!transfer.success_execute, E_UNAUTHORIZED);
    }

    public(friend) fun set_incoming_transfer_success(
        user: address,
        transfer_hash: vector<u8>
    ) acquires IncomingTransfers {
        let client = borrow_global_mut<IncomingTransfers>(user);
        let transfer = table::borrow_mut(&mut client.data,transfer_hash);
        transfer.success_execute = true;
    }

    public entry fun add_refund_request(
        user: address,
        transfer_hash: vector<u8>
    ) acquires RefundAccounts {
        let client = borrow_global_mut<RefundAccounts>(user);
        table::add(&mut client.data, transfer_hash, RefundAccount {
            status: 0,
        });

        event::emit(
            AddRefundRequestEvent {
                user_address: user,
                transfer_hash
            }
        );
    }

    public entry fun process_refund_request(
        sender: &signer,
        transfer_hash: vector<u8>,
        status: bool,
    ) acquires RefundAccounts, OutgoingTransfers {
        let user = signer::address_of(sender);

        let outgoing_transfers = borrow_global_mut<OutgoingTransfers>(user);
        let transfer = table::borrow_mut(&mut outgoing_transfers.data, transfer_hash);

        assert!(!transfer.success_execute && !transfer.refunded, E_UNAUTHORIZED);

        let refunds = borrow_global_mut<RefundAccounts>(user);

        let refund = table::borrow_mut(&mut refunds.data, transfer_hash);

        assert!(refund.status == 0, E_UNAUTHORIZED);

        transfer.refunded = true;

        if (status) {
            refund.status = 1;
        } else {
            refund.status = 2;
        }
    }

}
