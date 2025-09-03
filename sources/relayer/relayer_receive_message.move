module asterizm::relayer_receive_message {
    use std::signer;
    use supra_framework::event;

    use asterizm::relayer_settings;
    use asterizm::initializer_receive_message;

    // Error codes.

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 301;

    /// When invalid fee amount
    const ERR_INVALID_FEE: u64 = 302;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;
    
    #[event]
    struct TransferSendEvent has store, drop {
        src_chain_id: u64,
        src_address: address,
        dst_address: address,
        transfer_hash: vector<u8>,
    }

    struct TrTransferMessageRequestDto has copy, drop {
        src_chain_id: u64,
        src_address: address,
        dst_chain_id: u64,
        dst_address: address,
        tx_id: u128,
        transfer_hash: vector<u8>,
        relay_owner: address,
    }

    public entry fun transfer_message(
        account: &signer, 
        src_chain_id: u64, 
        src_address: address, 
        dst_address: address, 
        tx_id: u128, 
        transfer_hash: vector<u8>)  {

        relayer_settings::check_custom_relay(signer::address_of(account));

        initializer_receive_message::transfer_message(
            dst_address,
            src_address,
            src_chain_id,
            tx_id,
            transfer_hash
        );

        event::emit(
            TransferSendEvent {
                src_chain_id,
                src_address,
                dst_address,
                transfer_hash,
            }
        );
    }

    public entry fun transfer_sending_result(
        account: &signer,
        dst_address: address,
        transfer_hash: vector<u8>,
        status_code: u8,
        )  {

        relayer_settings::check_custom_relay(signer::address_of(account));

        initializer_receive_message::transfer_sending_result(
            dst_address,
            transfer_hash,
            status_code
        );
    }
}
