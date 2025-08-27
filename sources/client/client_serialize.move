module asterizm::client_serialize {
    use std::vector;
    use std::bcs;
    use std::hash;

    // Hash generation functions
    public fun serialize_message(
        src_chain_id: u64,
        src_address: address,
        dst_chain_id: u64,
        dst_address: address,
        tx_id: u128,
        payload: vector<u8>
    ): vector<u8> {
        let serialized = vector::empty();
        vector::append(&mut serialized, bcs::to_bytes(&src_chain_id));
        vector::append(&mut serialized, bcs::to_bytes(&src_address));
        vector::append(&mut serialized, bcs::to_bytes(&dst_chain_id));
        vector::append(&mut serialized, bcs::to_bytes(&dst_address));
        vector::append(&mut serialized, bcs::to_bytes(&tx_id));
        vector::append(&mut serialized, payload);
        serialized
    }

    public fun build_crosschain_hash(packed: vector<u8>): vector<u8> {
        if (vector::length(&packed) <= 112) {
            return hash::sha2_256(packed)
        };
        
        // Extract the static chunk (first 112 bytes)
        let static_chunk = vector::slice(&packed, 0, 112);
        let current_hash = hash::sha2_256(static_chunk);

        // Extract the payload chunk (remaining bytes after 112)
        let payload_chunk = vector::slice(&packed, 112, vector::length(&packed));
        let payload_length = vector::length(&payload_chunk);
        
        // Early return if payload is empty
        if (payload_length == 0) {
            return current_hash
        };

        let chunk_length = 127;
        // Calculate the number of chunks, adjusting if payload is a multiple of chunk length
        let limit_fix = if (payload_length % chunk_length == 0) {
            (payload_length / chunk_length) - 1
        } else {
            payload_length / chunk_length
        };

        // Process each chunk iteratively
        let i = 0;
        while (i <= limit_fix) {
            let from = i * chunk_length;
            let to = if (from + chunk_length <= payload_length) {
                from + chunk_length
            } else {
                payload_length
            };
            let chunk = vector::slice(&payload_chunk, from, to);
            let chunk_hash = hash::sha2_256(chunk);
            vector::append(&mut current_hash, chunk_hash);
            current_hash = hash::sha2_256(current_hash);
            i = i + 1;
        };

        current_hash
    }
}
