module asterizm::initializer_send_message {
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;

    use asterizm::relayer_send_message;
    use asterizm::relayer_settings;

    use asterizm::initializer_settings;

    friend asterizm::client_send_message;

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

    // Events
    struct TransferAccount has key {
        exists: bool
    }

    // Message Handling
    public(friend) fun send_message(
        account: &signer,
        relay_owner: address, 
        dst_chain_id: u64,
        src_address: address,
        dst_address: address,
        tx_id: u128, 
        transfer_result_notify_flag: bool,
        transfer_hash: vector<u8>,
        value: u64
    ) {
        // Check blocked accounts
        if (initializer_settings::check_address_is_blocked(src_address)) {
            abort ERR_BLOCKED_ACCOUNT
        };

        if (initializer_settings::check_address_is_blocked(dst_address)) {
            abort ERR_BLOCKED_ACCOUNT
        };

        let system_relayer_owner = relayer_settings::get_system_relayer_owner();

        if (relay_owner != system_relayer_owner) {
            let fee = relayer_settings::get_system_fee();
            coin::transfer<SupraCoin>(account, system_relayer_owner, fee);
        };

        // Send message to relayer
        relayer_send_message::send_message(
            account,
            relay_owner,
            dst_chain_id,
            src_address,
            dst_address,
            tx_id,
            transfer_result_notify_flag,
            transfer_hash,
            value
        );

    }

    public(friend) fun resend_message(
        account: &signer,
        relay_owner: address, 
        src_address: address,
        transfer_hash: vector<u8>,
        value: u64
    )  {
        
        // Check blocked accounts
        if (initializer_settings::check_address_is_blocked(src_address)) {
            abort ERR_BLOCKED_ACCOUNT
        };

        let system_relayer_owner = relayer_settings::get_system_relayer_owner();

        if (relay_owner != system_relayer_owner) {
            let fee = relayer_settings::get_system_fee();
            coin::transfer<SupraCoin>(account, system_relayer_owner, fee);
        };

        // Send message to relayer
        relayer_send_message::resend_message(
            account,
            relay_owner,
            src_address,
            transfer_hash,
            value
        );
    }
}
