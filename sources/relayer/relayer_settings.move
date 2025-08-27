module asterizm::relayer_settings {
    use std::signer;
    use supra_framework::event;
    use aptos_std::table::{Self, Table};


    // Error codes.

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 301;

    /// When invalid fee amount
    const ERR_INVALID_FEE: u64 = 302;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;

    /// Unreachable, is a bug if thrown
    const ERR_NOT_RELAY_OWNER: u64 = 304;
    
    struct RelayerSettings has key {
        system_relayer_owner: address,
        local_chain_id: u64,
        system_fee: u64,
    }

    struct CustomRelayers has key {
        data: Table<address, CustomRelayer>,
    }

    struct CustomRelayer has store, drop {
        fee: u64,
    }

    #[event]
    struct CreateRelayerSettingsEvent has store, drop {
        system_relayer_owner: address,
        local_chain_id: u64,
        system_fee: u64,
    }

    #[event]
    struct UpdateRelayerSettingsEvent has store, drop {
        system_fee: u64,
    }

    #[event]
    struct CreateCustomRelayEvent has store, drop {
        owner: address,
        fee: u64,
    }

    #[event]
    struct UpdateCustomRelayEvent has store, drop {
        owner: address,
        fee: u64,
    }


    public entry fun initialize(
        asterizm_admin: &signer, 
        system_relayer_owner: address, 
        local_chain_id: u64, 
        system_fee: u64
        ) {

        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);

        move_to<RelayerSettings>(asterizm_admin, RelayerSettings {
            system_relayer_owner,
            local_chain_id,
            system_fee,
        });
        
        event::emit(CreateRelayerSettingsEvent {
            system_relayer_owner,
            local_chain_id,
            system_fee,
        });

        let custom_relayers = table::new<address, CustomRelayer>();
        table::add(&mut custom_relayers, system_relayer_owner, CustomRelayer { fee: system_fee });

        move_to<CustomRelayers>(asterizm_admin, CustomRelayers {
            data: custom_relayers,
        });
    }

    public entry fun update_settings(
        asterizm_admin: &signer, 
        system_fee: u64
        ) acquires RelayerSettings {

        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);

        assert!(exists<RelayerSettings>(@asterizm), ERR_CONFIG_DOES_NOT_EXIST);

        let settings = borrow_global_mut<RelayerSettings>(@asterizm);

        settings.system_fee = system_fee;
        
        event::emit( UpdateRelayerSettingsEvent {
            system_fee,
        });
    }

    public entry fun create_custom_relay(
        asterizm_admin: &signer, 
        owner: address, 
        fee: u64
    ) acquires CustomRelayers {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);
        let custom_relayers = borrow_global_mut<CustomRelayers>(@asterizm);
        table::add(&mut custom_relayers.data, owner, CustomRelayer { fee});
    }

    public entry fun update_custom_relay(
        asterizm_admin: &signer, 
        owner: address, 
        fee: u64
    ) acquires CustomRelayers {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);
        let custom_relayers = borrow_global_mut<CustomRelayers>(@asterizm);

        let transfer = table::borrow_mut(&mut custom_relayers.data, owner);
        transfer.fee = fee;

        event::emit( UpdateCustomRelayEvent {
            owner,
            fee,
        });
    }

    public fun get_relay_fee(relay_owner: address): u64 acquires CustomRelayers {
        let custom_relayers = borrow_global<CustomRelayers>(@asterizm);
        assert!(table::contains(&borrow_global<CustomRelayers>(@asterizm).data, relay_owner), ERR_NOT_RELAY_OWNER);
        let transfer = table::borrow(&custom_relayers.data, relay_owner);
        transfer.fee
    }

    public fun check_custom_relay(relay_owner: address) acquires CustomRelayers {
        assert!(table::contains(&borrow_global<CustomRelayers>(@asterizm).data, relay_owner), ERR_NOT_RELAY_OWNER);
    }

    #[view]
    public fun get_local_chain_id(): u64 acquires RelayerSettings {
        assert!(exists<RelayerSettings>(@asterizm), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<RelayerSettings>(@asterizm);
        config.local_chain_id
    }

    #[view]
    public fun get_system_relayer_owner(): address acquires RelayerSettings {
        assert!(exists<RelayerSettings>(@asterizm), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<RelayerSettings>(@asterizm);
        config.system_relayer_owner
    }

    #[view]
    public fun get_system_fee(): u64 acquires RelayerSettings {
        assert!(exists<RelayerSettings>(@asterizm), ERR_CONFIG_DOES_NOT_EXIST);

        let config = borrow_global<RelayerSettings>(@asterizm);
        config.system_fee
    }
}
