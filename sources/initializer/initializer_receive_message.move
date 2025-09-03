module asterizm::initializer_receive_message {

    use asterizm::initializer_settings;
    use asterizm::client_receive_message;

    friend asterizm::relayer_receive_message;

    // Error codes.

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 301;

    /// When invalid fee amount
    const ERR_INVALID_FEE: u64 = 302;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;

    /// Account blocked
    const ERR_BLOCKED_ACCOUNT: u64 = 500;

    struct TransferAccount has key {
        exists: bool
    }

    public(friend) fun transfer_message(
        dst_address: address,
        src_address: address,
        src_chain_id: u64,
        tx_id: u128, 
        transfer_hash: vector<u8>,
    ) {

        // Check blocked accounts
        if (initializer_settings::check_address_is_blocked(src_address)) {
            abort ERR_BLOCKED_ACCOUNT
        };

        if (initializer_settings::check_address_is_blocked(dst_address)) {
            abort ERR_BLOCKED_ACCOUNT
        };

        // Send message to client
        client_receive_message::init_receive_message(
            dst_address,
            src_address,
            src_chain_id,
            tx_id,
            transfer_hash
        );

    }

    public(friend) fun transfer_sending_result(
        dst_address: address,
        transfer_hash: vector<u8>,
        status_code: u8,
    ) {

        client_receive_message::transfer_sending_result(
            dst_address,
            transfer_hash,
            status_code
        );

    }
}
