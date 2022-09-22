module pyth::pyth {
    use pyth::batch_price_attestation::{Self};
    use pyth::price_identifier::{Self, PriceIdentifier};
    use pyth::price_info::{Self, PriceInfo};
    use pyth::price_feed::{Self};
    use aptos_framework::coin::{Self, Coin, BurnCapability, MintCapability};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use pyth::i64;
    use pyth::price::Price;
    use pyth::price;
    use pyth::data_source::{Self, DataSource};
    use aptos_framework::timestamp;
    use std::vector;
    use pyth::state;
    use wormhole::vaa;
    use wormhole::u16;
    use wormhole::external_address;
    use std::account;
    use deployer::deployer;
    use pyth::error;

// -----------------------------------------------------------------------------
// Initialisation functions

    public entry fun init(
        deployer: &signer,
        chain_id: u64,
        stale_price_threshold: u64,
        governance_emitter_chain_id: u64,
        governance_emitter_address: vector<u8>,
        update_fee: u64,
    ) {
        // Claim the signer capability from the deployer. Note that this is a one-time operation,
        // so that this function can only be called once.
        let signer_capability = deployer::claim_signer_capability(deployer, @pyth);
        init_internal(
            signer_capability,
            chain_id,
            stale_price_threshold,
            governance_emitter_chain_id,
            governance_emitter_address,
            update_fee
        )
    }

    fun init_internal(
        signer_capability: account::SignerCapability,
        chain_id: u64,
        stale_price_threshold: u64,
        governance_emitter_chain_id: u64,
        governance_emitter_address: vector<u8>,
        update_fee: u64) {
        let pyth = account::create_signer_with_capability(&signer_capability);
        state::init(
            &pyth,
            chain_id,
            stale_price_threshold,
            update_fee,
            data_source::new(
                governance_emitter_chain_id,
                external_address::from_bytes(governance_emitter_address)),
            signer_capability
        );
        coin::register<AptosCoin>(&pyth);
    }

    #[test_only]
    /// Expose a public initialization function for use in tests
    public fun init_test(
        signer_capability: account::SignerCapability,
        chain_id: u64,
        stale_price_threshold: u64,
        governance_emitter_chain_id: u64,
        governance_emitter_address: vector<u8>,
        update_fee: u64,
    ) {
        init_internal(
            signer_capability,
            chain_id,
            stale_price_threshold,
            governance_emitter_chain_id,
            governance_emitter_address,
            update_fee
        )
    }

// -----------------------------------------------------------------------------
// Update the cached prices

    /// Update the cached price feeds with the data in the given vaa_bytes payload.
    /// The given fee must contain a sufficient number of coins to pay the update fee:
    /// this amount can be queried by calling get_update_fee().
    public entry fun update_price_feeds(vaa_bytes: vector<u8>, fee: Coin<AptosCoin>) {
        // Deserialize the VAA
        let vaa = vaa::parse_and_verify(vaa_bytes);

        // Charge the message update fee
        assert!(state::get_update_fee() <= coin::value(&fee), error::insufficient_fee());
        coin::deposit(@pyth, fee);

        // Check that the VAA is from a valid data source (emitter)
        assert!(
            state::is_valid_data_source(
                data_source::new(
                    u16::to_u64(vaa::get_emitter_chain(&vaa)),
                    vaa::get_emitter_address(&vaa))),
            error::invalid_data_source());

        // Deserialize the batch price attestation
        update_cache(batch_price_attestation::destroy(
                batch_price_attestation::deserialize(vaa::destroy(vaa))));
    }

    /// Update the cache with given price updates, if they are newer than the ones currently cached.
    fun update_cache(updates: vector<PriceInfo>) {
        while (!vector::is_empty(&updates)) {
            let update = vector::pop_back(&mut updates);
            if (is_fresh_update(&update)) {
                let price_feed = price_info::get_price_feed(&update);
                let price_identifier = price_feed::get_price_identifier(price_feed);
                state::set_latest_price_info(
                    *price_identifier,
                    update,
                )
            }
        };
        vector::destroy_empty(updates);
    }

    /// Update the cached price feeds with the data in the given vaa_bytes payload, using
    /// update_price_feeds(). However, this function will only have an effect if any of the
    /// prices in the update are fresh. The price_identifiers and publish_times paramaters
    /// are used to determine if the update is fresh without doing any serialisation or verification
    /// of the VAA, potentially saving time and gas. If the update contains no fresh data, this function
    /// will revert with error::no_fresh_data(). 
    /// 
    /// For a given price update i in the batch, that price is considered fresh if the current cached 
    /// price for price_identifiers[i] is older than publish_times[i].
    public entry fun update_price_feeds_if_fresh(
        vaa_bytes: vector<u8>,
        price_identifiers: vector<PriceIdentifier>,
        publish_times: vector<u64>,
        fee: Coin<AptosCoin>) {

        assert!(vector::length(&price_identifiers) == vector::length(&publish_times),
            error::invalid_publish_times_length());

        let fresh_data = false;
        let i = 0;
        while (i < vector::length(&publish_times)) {
            let price_identifier = vector::borrow(&price_identifiers, i);
            if (!state::price_info_cached(*price_identifier)) {
                fresh_data = true;
                break
            };

            let cached_timestamp = price::get_timestamp(&get_price_unsafe(*price_identifier));
            if (cached_timestamp < *vector::borrow(&publish_times, i)) {
                fresh_data = true;
                break
            };

            i = i + 1;
        };

        assert!(fresh_data, error::no_fresh_data());
        update_price_feeds(vaa_bytes, fee);
    }

    /// Determine if the given price update is "fresh": we have nothing newer already cached for that
    /// price feed.
    fun is_fresh_update(update: &PriceInfo): bool {
        // Get the timestamp of the update's current price
        let price_feed = price_info::get_price_feed(update);
        let update_timestamp = price::get_timestamp(&price_feed::get_price(price_feed));

        // Get the timestamp of the cached data for the price identifier
        let price_identifier = price_feed::get_price_identifier(price_feed);
        if (!price_feed_exists(*price_identifier)) {
            return true
        };
        let cached_timestamp = price::get_timestamp(&get_price_unsafe(*price_identifier));
        
        update_timestamp > cached_timestamp
    }

// -----------------------------------------------------------------------------
// Query the cached prices
//
// It is strongly recommended to update the cached prices using the functions above,
// before using the functions below to query the cached data.

    /// Determine if a price feed for the given price_identifier exists
    public fun price_feed_exists(price_identifier: PriceIdentifier): bool {
        state::price_info_cached(price_identifier)
    }

    /// Get the latest cached data for the given price identifier, if that data is 
    /// no older than the stale price threshold.
    /// 
    /// Important: it is recommended to call update_price_feeds() to update the cached data
    /// before calling this function.
    public fun get_price(price_identifier: PriceIdentifier): Price {
        get_price_no_older_than(price_identifier, state::get_stale_price_threshold_secs())
    }

    /// Get the latest cached data for the given price identifier, if that data is 
    /// no older than the given age.
    public fun get_price_no_older_than(price_identifier: PriceIdentifier, max_age_secs: u64): Price {
        let price = get_price_unsafe(price_identifier);
        let age = abs_diff(timestamp::now_seconds(), price::get_timestamp(&price));

        assert!(age < max_age_secs, error::stale_price_update());

        price
    }

    /// Get the latest cached exponential moving average price for the given price_identifier.
    public fun get_ema_price(price_identifier: PriceIdentifier): Price {
        price_feed::get_ema_price(
            price_info::get_price_feed(&state::get_latest_price_info(price_identifier)))
    }

    /// Get the latest available price for the given price identifier.
    /// 
    /// WARNING: the returned price can be from arbitrarily far in the past.
    /// This function makes no guarantees that the returned price is recent or
    /// useful for any particular application. Users of this function should check
    /// the returned timestamp to ensure that the returned price is sufficiently 
    /// recent for their application. The checked get_price_no_older_than()
    /// function should be used in preference to this.
    public fun get_price_unsafe(price_identifier: PriceIdentifier): Price {
        price_feed::get_price(
            price_info::get_price_feed(&state::get_latest_price_info(price_identifier)))
    }

    fun abs_diff(x: u64, y: u64): u64 {
        if (x > y) {
            return x - y
        } else {
            return y - x
        }
    }

    /// Get the stale price threshold: the amount of time after which a cached price
    /// is considered stale and no longer returned by get_price().
    public fun get_stale_price_threshold_secs(): u64 {
        state::get_stale_price_threshold_secs()
    }

    /// Get the number of AptosCoin's required to perform one batch update
    public fun get_update_fee(): u64 {
        state::get_update_fee()
    }

// -----------------------------------------------------------------------------
// Tests

    #[test_only]
    fun setup_test(
        aptos_framework: &signer,
        chain_id: u64,
        stale_price_threshold: u64,
        governance_emitter_chain_id: u64,
        governance_emitter_address: vector<u8>,
        update_fee: u64,
        to_mint: u64): (BurnCapability<AptosCoin>, MintCapability<AptosCoin>, Coin<AptosCoin>) {
        // Initialize wormhole with a large message collection fee
        wormhole::wormhole_test::setup(100000);

        // Set the current time
        timestamp::update_global_time_for_test_secs(1663680745);

        // Deploy and initialize a test instance of the Pyth contract
        let deployer = account::create_signer_with_capability(&
            account::create_test_signer_cap(@0x277fa055b6a73c42c0662d5236c65c864ccbf2d4abd21f174a30c8b786eab84b));
        let (_pyth, signer_capability) = account::create_resource_account(&deployer, b"pyth");
        init_test(signer_capability, chain_id, stale_price_threshold, governance_emitter_chain_id, governance_emitter_address, update_fee);
    
        let (burn_capability, mint_capability) = aptos_coin::initialize_for_test(aptos_framework);
        let coins = coin::mint(to_mint, &mint_capability);
        (burn_capability, mint_capability, coins)
    }

    #[test_only]
    fun cleanup_test(burn_capability: BurnCapability<AptosCoin>, mint_capability: MintCapability<AptosCoin>) {
        coin::destroy_mint_cap(mint_capability);
        coin::destroy_burn_cap(burn_capability);
    }

    #[test_only]
    fun get_mock_price_infos(): vector<PriceInfo> {
        vector<PriceInfo>[
                price_info::new(
                    1663680747,
                    1663074349,
                    price_feed::new(
                        price_identifier::from_byte_vec(x"c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1"),
                        price::new(i64::new(1557, false), 7, i64::new(5, true), 1663680740),
                        price::new(i64::new(1500, false), 3, i64::new(5, true), 1663680740),
                    ),
                ),
                price_info::new(
                    1663680747,
                    1663074349,
                    price_feed::new(
                        price_identifier::from_byte_vec(x"3b9551a68d01d954d6387aff4df1529027ffb2fee413082e509feb29cc4904fe"),
                        price::new(i64::new(1050, false), 3, i64::new(5, true), 1663680745),
                        price::new(i64::new(1483, false), 3, i64::new(5, true), 1663680745),
                    ),
                ),
                price_info::new(
                    1663680747,
                    1663074349,
                    price_feed::new(
                        price_identifier::from_byte_vec(x"33832fad6e36eb05a8972fe5f219b27b5b2bb2230a79ce79beb4c5c5e7ecc76d"),
                        price::new(i64::new(1010, false), 2, i64::new(5, true), 1663680745),
                        price::new(i64::new(1511, false), 3, i64::new(5, true), 1663680745),
                    ),
                ),
                price_info::new(
                    1663680747,
                    1663074349,
                    price_feed::new(
                        price_identifier::from_byte_vec(x"21a28b4c6619968bd8c20e95b0aaed7df2187fd310275347e0376a2cd7427db8"),
                        price::new(i64::new(1739, false), 1, i64::new(5, true), 1663680745),
                        price::new(i64::new(1508, false), 3, i64::new(5, true), 1663680745),
                    ),
                ),
            ]
    }

    #[test_only]
    /// A VAA with:
    /// - emitter chain ID 17
    /// - emitter address 0x71f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b
    /// - payload corresponding to the batch price attestation of the prices returned by get_mock_price_infos()
    const TEST_VAA: vector<u8> = x"0100000000010036eb563b80a24f4253bee6150eb8924e4bdf6e4fa1dfc759a6664d2e865b4b134651a7b021b7f1ce3bd078070b688b6f2e37ce2de0d9b48e6a78684561e49d5201527e4f9b00000001001171f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b0000000000000001005032574800030000000102000400951436e0be37536be96f0896366089506a59763d036728332d3e3038047851aea7c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1000000000000049a0000000000000008fffffffb00000000000005dc0000000000000003000000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000006150000000000000007215258d81468614f6b7e194c5d145609394f67b041e93e6695dcc616faadd0603b9551a68d01d954d6387aff4df1529027ffb2fee413082e509feb29cc4904fe000000000000041a0000000000000003fffffffb00000000000005cb0000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e4000000000000048600000000000000078ac9cf3ab299af710d735163726fdae0db8465280502eb9f801f74b3c1bd190333832fad6e36eb05a8972fe5f219b27b5b2bb2230a79ce79beb4c5c5e7ecc76d00000000000003f20000000000000002fffffffb00000000000005e70000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e40000000000000685000000000000000861db714e9ff987b6fedf00d01f9fea6db7c30632d6fc83b7bc9459d7192bc44a21a28b4c6619968bd8c20e95b0aaed7df2187fd310275347e0376a2cd7427db800000000000006cb0000000000000001fffffffb00000000000005e40000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000007970000000000000001";

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 6)]
    fun test_update_price_feeds_corrupt_vaa(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 100);

        // Pass in a corrupt VAA, which should fail deseriaizing
        let corrupt_vaa = x"90F8bf6A479f320ead074411a4B0e7944Ea8c9C1";
        update_price_feeds(corrupt_vaa, coins);

        cleanup_test(burn_capability, mint_capability);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 65539)]
    fun test_update_price_feeds_invalid_data_source_initially(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 100);
        
        // Without setting any valid data source, the check should fail
        update_price_feeds(TEST_VAA, coins);

        cleanup_test(burn_capability, mint_capability);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 65539)]
    fun test_update_price_feeds_invalid_data_source(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 100);
        
        // Set some valid data sources, excluding our test VAA's source
        state::set_data_sources(vector<DataSource>[
            data_source::new(
                4, external_address::from_bytes(x"0000000000000000000000000000000000000000000000000000000000007742")),
                data_source::new(
                5, external_address::from_bytes(x"0000000000000000000000000000000000000000000000000000000000007637"))
        ]);

        update_price_feeds(TEST_VAA, coins);

        cleanup_test(burn_capability, mint_capability);
    }

    #[test_only]
    fun set_data_source_for_test_vaa() {
        // Set some valid data sources, including our test VAA's source
        state::set_data_sources(vector<DataSource>[
            data_source::new(
                1, external_address::from_bytes(x"0000000000000000000000000000000000000000000000000000000000000004")),
                data_source::new(
                5, external_address::from_bytes(x"0000000000000000000000000000000000000000000000000000000000007637")),
                data_source::new(
                17, external_address::from_bytes(x"71f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b"))
        ]);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 65542)]
    fun test_update_price_feeds_insufficient_fee(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1,
            x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92",
            // Update fee
            50,
            // Coins provided to update < update fee
            20);

        // Set some valid data sources, excluding our test VAA's source
        state::set_data_sources(vector<DataSource>[
            data_source::new(
                1, external_address::from_bytes(x"0000000000000000000000000000000000000000000000000000000000000004")),
                data_source::new(
                5, external_address::from_bytes(x"0000000000000000000000000000000000000000000000000000000000007637"))
        ]);

        update_price_feeds(TEST_VAA, coins);

        cleanup_test(burn_capability, mint_capability);
    }

    #[test(aptos_framework = @aptos_framework)]
    fun test_update_price_feeds_success(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 100);

        set_data_source_for_test_vaa();
    
        // Update the price feeds from the VAA
        update_price_feeds(TEST_VAA, coins);

        // Check that the cache has been updated
        let expected = get_mock_price_infos();
        check_price_feeds_cached(&expected);

        cleanup_test(burn_capability, mint_capability);
    }

    #[test_only]
    fun check_price_feeds_cached(expected: &vector<PriceInfo>) {

        // Check that we can retrieve the correct current price and ema price for each price feed
        let i = 0;
        while (i < vector::length(expected)) {
            let price_feed = price_info::get_price_feed(vector::borrow(expected, i));
            let price = price_feed::get_price(price_feed);

            let price_identifier = *price_feed::get_price_identifier(price_feed);
            assert!(price_feed_exists(price_identifier), 1);
            let cached_price = get_price(price_identifier);

            assert!(cached_price == price, 1);

            let ema_price = price_feed::get_ema_price(price_feed);
            let cached_ema_price = get_ema_price(price_identifier);

            assert!(cached_ema_price == ema_price, 1);

            i = i + 1;
        };

    }

    #[test(aptos_framework = @aptos_framework)]
    fun test_update_cache(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 0);

        let updates = get_mock_price_infos();

        // Check that initially the price feeds are not cached
        let i = 0;
        while (i < vector::length(&updates)) {
            let price_feed = price_info::get_price_feed(vector::borrow(&updates, i));
            assert!(!price_feed_exists(*price_feed::get_price_identifier(price_feed)), 1);
            i = i + 1;
        };
        
        // Submit the updates
        update_cache(updates);

        // Check that the price feeds are now cached
        check_price_feeds_cached(&updates);

        cleanup_test(burn_capability, mint_capability);
        coin::destroy_zero(coins);
    }

    #[test(aptos_framework = @aptos_framework)]
    fun test_update_cache_old_update(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 0);
        
        // Submit a price update
        let timestamp = 1663680700;
        let price_identifier = price_identifier::from_byte_vec(x"baa284eaf23edf975b371ba2818772f93dbae72836bbdea28b07d40f3cf8b485");
        let price = price::new(i64::new(7648, false), 674, i64::new(8, true), timestamp);
        let ema_price = price::new(i64::new(1536, true), 869, i64::new(100, false), 1257212500);
        let update = price_info::new(
            1257278600,
            1690226180,
            price_feed::new(
                    price_identifier,
                    price,
                    ema_price,
            )
        );
        update_cache(vector<PriceInfo>[update]);

        // Check that we can retrieve the current price
        assert!(get_price(price_identifier) == price, 1);

        // Attempt to update the price with an update older than the current cached one
        let old_price = price::new(i64::new(1243, true), 9802, i64::new(6, false), timestamp - 200);
        let old_ema_price = price::new(i64::new(8976, true), 234, i64::new(897, false), timestamp - 200);
        let old_update = price_info::new(
            1257278600,
            1690226180,
            price_feed::new(
                    price_identifier,
                    old_price,
                    old_ema_price,
            )
        );
        update_cache(vector<PriceInfo>[old_update]);

        // Confirm that the current price and ema price didn't change
        assert!(get_price(price_identifier) == price, 1);
        assert!(get_ema_price(price_identifier) == ema_price, 1);

        // Update the cache with a fresh update 
        let fresh_price = price::new(i64::new(4857, true), 9979, i64::new(243, false), timestamp + 200);
        let fresh_ema_price = price::new(i64::new(74637, false), 9979, i64::new(1433, false), timestamp + 1);
        let fresh_update = price_info::new(
            1257278600,
            1690226180,
            price_feed::new(
                    price_identifier,
                    fresh_price,
                    fresh_ema_price,
            )
        );
        update_cache(vector<PriceInfo>[fresh_update]);

        // Confirm that the current price was updated
        assert!(get_price(price_identifier) == fresh_price, 1);
        assert!(get_ema_price(price_identifier) == fresh_ema_price, 1);

        cleanup_test(burn_capability, mint_capability);
        coin::destroy_zero(coins);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 524292)]
    fun test_stale_price_threshold_exceeded(aptos_framework: &signer) {
        let stale_price_threshold = 500;
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, stale_price_threshold, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 0);

        // Submit a price update
        let current_timestamp = timestamp::now_seconds();
        let price_identifier = price_identifier::from_byte_vec(x"baa284eaf23edf975b371ba2818772f93dbae72836bbdea28b07d40f3cf8b485");
        let price = price::new(i64::new(7648, false), 674, i64::new(8, true), current_timestamp);
        let update = price_info::new(
            1257278600,
            1690226180,
            price_feed::new(
                    price_identifier,
                    price,
                    price::new(i64::new(1536, true), 869, i64::new(100, false), 1257212500),
            )
        );
        update_cache(vector<PriceInfo>[update]);
        assert!(get_price(price_identifier) == price, 1);

        // Now advance the clock on the target chain, until the age of the cached update exceeds the
        // stale_price_threshold.
        timestamp::update_global_time_for_test_secs(current_timestamp + stale_price_threshold);

        // Check that we can access the price if we increase the threshold by 1
        assert!(get_price_no_older_than(
            price_identifier, get_stale_price_threshold_secs() + 1) == price, 1);

        // However, retrieving the latest price fails
        assert!(get_price(price_identifier) == price, 1);

        cleanup_test(burn_capability, mint_capability);
        coin::destroy_zero(coins);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 65541)]
    fun test_update_price_feeds_if_fresh_invalid_length(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 0);
        
        // Update the price feeds 
        let bytes = vector[0u8, 1u8, 2u8];
        let price_identifiers = vector[
            price_identifier::from_byte_vec(x"baa284eaf23edf975b371ba2818772f93dbae72836bbdea28b07d40f3cf8b485"),
            price_identifier::from_byte_vec(x"c9d5fe0d836688f4c88c221415d23e4bcabee21a6a21124bfcc9a5410a297818"),
            price_identifier::from_byte_vec(x"eaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a"),
        ];
        let publish_times = vector[
            734639463
        ];
        update_price_feeds_if_fresh(bytes, price_identifiers, publish_times, coins);

        cleanup_test(burn_capability, mint_capability);
    }

    #[test(aptos_framework = @aptos_framework)]
    fun test_update_price_feeds_if_fresh_fresh_data(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 50);
        set_data_source_for_test_vaa();
        
        // Update the price feeds 
        let bytes = TEST_VAA;
        let price_identifiers = vector[
            price_identifier::from_byte_vec(x"c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1"),
            price_identifier::from_byte_vec(x"3b9551a68d01d954d6387aff4df1529027ffb2fee413082e509feb29cc4904fe"),
            price_identifier::from_byte_vec(x"33832fad6e36eb05a8972fe5f219b27b5b2bb2230a79ce79beb4c5c5e7ecc76d"),
            price_identifier::from_byte_vec(x"21a28b4c6619968bd8c20e95b0aaed7df2187fd310275347e0376a2cd7427db8"),
        ];
        let publish_times = vector[
            1663680745, 1663680730, 1663680760, 1663680720
        ];
        update_price_feeds_if_fresh(bytes, price_identifiers, publish_times, coins);

        // Check that the cache has been updated
        let expected = get_mock_price_infos();
        check_price_feeds_cached(&expected);

        cleanup_test(burn_capability, mint_capability);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 524295)]
    fun test_update_price_feeds_if_fresh_stale_data(aptos_framework: &signer) {
        let (burn_capability, mint_capability, coins) = setup_test(aptos_framework, 27, 500, 1, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", 50, 50);
        set_data_source_for_test_vaa();

        // First populate the cache
        update_cache(get_mock_price_infos());
        
        // Now attempt to update the price feeds with publish_times that are older than those we have cached
        // This should abort with error::no_fresh_data()
        let bytes = TEST_VAA;
        let price_identifiers = vector[
            price_identifier::from_byte_vec(x"c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1"),
            price_identifier::from_byte_vec(x"3b9551a68d01d954d6387aff4df1529027ffb2fee413082e509feb29cc4904fe"),
            price_identifier::from_byte_vec(x"33832fad6e36eb05a8972fe5f219b27b5b2bb2230a79ce79beb4c5c5e7ecc76d"),
            price_identifier::from_byte_vec(x"21a28b4c6619968bd8c20e95b0aaed7df2187fd310275347e0376a2cd7427db8"),
        ];
        let publish_times = vector[
            67, 35, 26, 64
        ];
        update_price_feeds_if_fresh(bytes, price_identifiers, publish_times, coins);

        cleanup_test(burn_capability, mint_capability);
    }
}
