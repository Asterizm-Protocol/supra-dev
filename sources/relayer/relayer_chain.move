module asterizm::relayer_chain {
    use std::signer;
    use std::string::String;
    use std::event;
    use aptos_std::table::{Self, Table};

    // Error codes.

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 301;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;

    struct Chains has key {
        data: Table<u64, Chain> 
    }
    
    struct Chain has store {
        name: String,
        id: u64,
        chain_type: u8,
    }

    #[event]
    struct CreateChainEvent  has drop, store {
        name: String,
        id: u64,
    }

    #[event]
    struct UpdateChainTypeEvent  has drop, store {
        id: u64,
        chain_type: u8,
    }

    public entry fun create_chain(asterizm_admin: &signer, id: u64, name: String, chain_type: u8) acquires Chains {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);

        if (exists<Chains>(@asterizm) == false) {
            move_to<Chains>(asterizm_admin, Chains {
                data: table::new<u64, Chain>(),
            });
        };

        let container = borrow_global_mut<Chains>(@asterizm);
        table::add(&mut container.data, id, Chain { name, id, chain_type });

        event::emit(CreateChainEvent {
            name,
            id,
        });
    }

    public entry fun update_chain_type(asterizm_admin: &signer, id: u64, chain_type: u8) acquires Chains {
        assert!(signer::address_of(asterizm_admin) == @asterizm, ERR_UNREACHABLE);

        let chain = table::borrow_mut(&mut borrow_global_mut<Chains>(@asterizm).data, id);
        chain.chain_type = chain_type;

        event::emit( UpdateChainTypeEvent {
            id,
            chain_type,
        });
    }

    public fun get_chain_type(chain_id: u64): u8 acquires Chains {
        let container = borrow_global<Chains>(@asterizm);
        table::borrow(&container.data, chain_id).chain_type
    }
}

