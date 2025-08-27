module asterizm::client_settings {
    use std::signer;

    use aptos_std::event;
    
    const E_NOT_INITIALIZED: u64 = 0;
    const E_UNAUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INVALID_HASH: u64 = 3;
    const E_TRANSFER_EXISTS: u64 = 4;

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;
    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;
    
    struct ClientSettings has key {
        local_chain_id: u64,
    }

    // Events
    #[event]
    struct CreateClientSettingsEvent has drop, store {
        local_chain_id: u64,
    }

    // Module initialization
    public entry fun initialize(asterizm_admin: &signer, local_chain_id: u64)  {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);
        
        assert!(!exists<ClientSettings>(@asterizm), E_ALREADY_INITIALIZED);
        
        move_to(asterizm_admin, ClientSettings {
            local_chain_id,
        });

        event::emit(
            CreateClientSettingsEvent {
                local_chain_id
            }
        );
    }

    #[view]
    public fun get_local_chain_id(): u64 acquires ClientSettings {
        assert!(exists<ClientSettings>(@asterizm), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<ClientSettings>(@asterizm);
        config.local_chain_id
    }
}
