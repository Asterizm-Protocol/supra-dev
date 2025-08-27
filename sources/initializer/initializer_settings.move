module asterizm::initializer_settings {
    use std::signer;
    use aptos_std::table::{Self, Table};
    use supra_framework::event;

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
    #[event]
    struct CreateInitializerSettingsEvent has store, drop {
        local_chain_id: u64,
    }

    #[event]
    struct BlockAccountEvent has drop, store {
        chain_id: u64,
        user_address: address
    }

    #[event]
    struct UnblockAccountEvent has drop, store {
        user_address: address
    }

    // Resources
    struct InitializerSettings has key {
        is_initialized: bool,
        local_chain_id: u64
    }

    struct BlockedAccounts has key {
        data: Table<address, BlockedAccount> 
    }

    struct BlockedAccount has drop, store {
        is_blocked: bool,
        chain_id: u64,
        user_address: address,
    }

    struct TransferAccount has key {
        exists: bool
    }

    // Module Initialization
    public entry fun initialize(
        asterizm_admin: &signer,
        local_chain_id: u64,
    )  {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);
        
        move_to(asterizm_admin, InitializerSettings {
            is_initialized: true,
            local_chain_id
        });

        move_to<BlockedAccounts>(asterizm_admin, BlockedAccounts {
            data: table::new<address, BlockedAccount>(),
        });

        event::emit(
            CreateInitializerSettingsEvent {
                local_chain_id
            }
        );
    }

    // Account Blocking
    public entry fun block_account(
        asterizm_admin: &signer,
        chain_id: u64,
        user_address: address
    ) acquires InitializerSettings, BlockedAccounts {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);
        let settings = borrow_global<InitializerSettings>(@asterizm);
        assert!(settings.is_initialized, ERR_UNREACHABLE);

        let container = borrow_global_mut<BlockedAccounts>(@asterizm);
        table::add(&mut container.data, user_address, BlockedAccount { is_blocked: true, chain_id, user_address });

        event::emit(
            BlockAccountEvent {
                chain_id,
                user_address
            }
        );
    }
    
    public entry fun unblock_account(
        asterizm_admin: &signer,
        user_address: address
    ) acquires InitializerSettings, BlockedAccounts {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);
        let settings = borrow_global<InitializerSettings>(@asterizm);
        assert!(settings.is_initialized, ERR_UNREACHABLE);

        let container = borrow_global_mut<BlockedAccounts>(@asterizm);
        table::remove(&mut container.data, user_address);

        event::emit(
            UnblockAccountEvent {
                user_address
            }
        );
    }

    #[view]
    public fun get_local_chain_id(): u64 acquires InitializerSettings {
        assert!(exists<InitializerSettings>(@asterizm), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<InitializerSettings>(@asterizm);
        config.local_chain_id
    }

    #[view]
    public fun check_address_is_blocked(src_address: address): bool acquires BlockedAccounts {
        table::contains(&borrow_global<BlockedAccounts>(@asterizm).data, src_address)
    }
}
