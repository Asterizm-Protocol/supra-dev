module asterizm::relayer_send_message {
    use std::vector;
    use std::bcs;
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::event;

    use asterizm::relayer_settings;

    friend asterizm::initializer_send_message;

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
    struct SendRelayerFeeEvent has store, drop {
        relay_account_owner: address,
        fee: u64,
    }
    
    #[event]
    struct SendMessageEvent has store, drop {
        value: u64,
        payload: vector<u8>,
    }
    
    #[event]
    struct ResendFailedTransferEvent has store, drop {
        src_address: address,
        transfer_hash: vector<u8>,
        value: u64,
    }
    
    struct TrSendMessageRequestDto has copy, drop {
        src_chain_id: u64,
        src_address: address,
        dst_chain_id: u64,
        dst_address: address,
        tx_id: u128,
        transfer_result_notify_flag: bool,
        transfer_hash: vector<u8>,
        relay_owner: address,
    }
    
    public(friend) fun send_message(
        account: &signer, 
        relay_owner: address, 
        dst_chain_id: u64, 
        src_address: address, 
        dst_address: address, 
        tx_id: u128, 
        transfer_result_notify_flag: bool, 
        transfer_hash: vector<u8>, 
        value: u64)       {
        let local_chain_id = relayer_settings::get_local_chain_id();

        let dto = TrSendMessageRequestDto {
            src_chain_id: local_chain_id,
            src_address,
            dst_chain_id,
            dst_address,
            tx_id,
            transfer_result_notify_flag,
            transfer_hash,
            relay_owner,
        };

        let payload = serialize_dto(dto);

        // Note: Transfer funds should be implemented here.
        let relay_account_fee = relayer_settings::get_relay_fee(relay_owner);

        if (value < relay_account_fee) {
            abort ERR_INVALID_FEE
        } else {
            coin::transfer<SupraCoin>(account, relay_owner, value);
        };

        event::emit(
            SendRelayerFeeEvent {
                relay_account_owner: relay_owner,
                fee: relay_account_fee,
            }
        );

        event::emit(
             SendMessageEvent {
                value,
                payload,
            }
        );
    }
    
    public(friend) fun resend_message(
        account: &signer, 
        relay_owner: address, 
        src_address: address,
        transfer_hash: vector<u8>, 
        value: u64){
        let relay_account_fee = relayer_settings::get_relay_fee(relay_owner);
        if (value < relay_account_fee) {
            abort ERR_INVALID_FEE
        } else {
            coin::transfer<SupraCoin>(account, relay_owner, value);
        };

        event::emit(
            SendRelayerFeeEvent {
                relay_account_owner: relay_owner,
                fee: relay_account_fee,
            }
        );

        event::emit( ResendFailedTransferEvent {
            src_address,
            transfer_hash,
            value,
        });
    }
    
    fun serialize_dto(dto: TrSendMessageRequestDto): vector<u8> {
        let serialized = vector::empty();
        vector::append(&mut serialized, bcs::to_bytes(&dto.src_chain_id));
        vector::append(&mut serialized, bcs::to_bytes(&dto.src_address));
        vector::append(&mut serialized, bcs::to_bytes(&dto.dst_chain_id));
        vector::append(&mut serialized, bcs::to_bytes(&dto.dst_address));
        vector::append(&mut serialized, bcs::to_bytes(&dto.tx_id));
        vector::append(&mut serialized, bcs::to_bytes(&dto.transfer_result_notify_flag));
        vector::append(&mut serialized, bcs::to_bytes(&dto.transfer_hash));
        vector::append(&mut serialized, bcs::to_bytes(&dto.relay_owner));
        serialized
    }
}
