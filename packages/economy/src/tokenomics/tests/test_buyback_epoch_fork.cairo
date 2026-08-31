/// Does the CONFIG EPOCH hold up against the real Ekubo?
///
/// The unit suite proves the component's epoch bookkeeping with Ekubo mocked
/// out, and `test_ekubo_mixed_keys_fork` proves Ekubo tolerates mixed order keys
/// under one position. Neither proves the two together: that a fee change
/// mid-flight produces orders Ekubo will actually PAY OUT, each against the key
/// the component rebuilt from its own epoch.
///
/// That is the property `claim_buyback_proceeds` depends on, and the one where a
/// mistake strands funds rather than merely rejecting a call — an order that can
/// be created but not withdrawn is worse than one that was never created.
///
/// So: real Ekubo on Sepolia, real liquidity, one BuybackComponent, two orders
/// either side of a fee-tier change, then claim both.
#[cfg(test)]
mod buyback_epoch_fork_tests {
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use ekubo::types::bounds::max_bounds;
    use ekubo::types::i129::i129;
    use ekubo::types::keys::PoolKey;
    use game_components_interfaces::tokenomics::buyback::{
        BuybackParams, GlobalBuybackConfig, IBuybackAdminDispatcher, IBuybackAdminDispatcherTrait,
        IBuybackDispatcher, IBuybackDispatcherTrait, TokenBuybackConfig,
    };
    use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use snforge_std::{
        load, start_cheat_block_timestamp_global, start_cheat_caller_address,
        stop_cheat_block_timestamp_global, stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, get_block_timestamp};
    use super::super::helpers::deployment::deploy_autonomous_buyback;

    const POSITIONS: felt252 = 0x06a2aee84bb0ed5dded4384ddd0e40e9c1372b818668375ab8e3ec08807417e5;
    const TWAMM: felt252 = 0x073ec792c33b52d5f96940c2860d512b3884f2127d25e023eb9d44a678e4b971;
    const STRK: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
    const BUDOKAN: felt252 = 0x00886cabf9da06823eabbe4e6e806384d2af66d7f33cd654a724f85348e5c286;
    /// Holds both tokens on Sepolia at the pinned block.
    const WHALE: felt252 = 0x48fde8afe1f0976568b411c75d5f65a9175189514f101132bcd524a96ae8648;

    const FEE_A: u128 = 170141183460469235273462165868118016; // 0.05%
    const FEE_B: u128 = 1020847100762815390390123822295304634; // 0.3%
    const MAX_TICK_SPACING: u128 = 354892;

    const ONE: u128 = 1000000000000000000;
    const MIN_DURATION: u64 = 259200;
    const MAX_DURATION: u64 = 604800;

    fn addr(v: felt252) -> ContractAddress {
        v.try_into().unwrap()
    }

    fn owner() -> ContractAddress {
        'OWNER'.try_into().unwrap()
    }

    fn treasury() -> ContractAddress {
        'TREASURY'.try_into().unwrap()
    }

    fn pool_key_for(fee: u128) -> PoolKey {
        let strk: u256 = STRK.into();
        let budokan: u256 = BUDOKAN.into();
        let (token0, token1) = if strk > budokan {
            (addr(BUDOKAN), addr(STRK))
        } else {
            (addr(STRK), addr(BUDOKAN))
        };
        PoolKey { token0, token1, fee, tick_spacing: MAX_TICK_SPACING, extension: addr(TWAMM) }
    }

    /// Ekubo requires order boundaries on a coarse grid; 2**16 is the step our
    /// live orders use.
    fn valid_end_time() -> u64 {
        let step: u64 = 65536;
        ((get_block_timestamp() + MIN_DURATION + 40000) / step + 1) * step
    }

    fn whale_send(token: felt252, to: ContractAddress, amount: u128) {
        let erc20 = IERC20Dispatcher { contract_address: addr(token) };
        start_cheat_caller_address(addr(token), addr(WHALE));
        erc20.transfer(to, amount.into());
        stop_cheat_caller_address(addr(token));
    }

    /// Both pools need liquidity, or the TWAMM sells into nothing and every
    /// claim pays out zero — which would make this test pass without proving a
    /// payout ever happened.
    fn seed_pool(positions: IPositionsDispatcher, core: ICoreDispatcher, fee: u128) {
        let pool_key = pool_key_for(fee);
        let _ = core.maybe_initialize_pool(pool_key, i129 { mag: 0, sign: false });
        whale_send(STRK, addr(POSITIONS), 200 * ONE);
        whale_send(BUDOKAN, addr(POSITIONS), 200 * ONE);
        positions.mint_and_deposit(pool_key, max_bounds(MAX_TICK_SPACING), 0);
    }

    #[test]
    #[fork("SEPOLIA")]
    fn fee_change_mid_flight_still_pays_out_both_orders() {
        let positions = IPositionsDispatcher { contract_address: addr(POSITIONS) };
        let core_felt = *load(addr(POSITIONS), selector!("core"), 1).at(0);
        let core = ICoreDispatcher { contract_address: core_felt.try_into().unwrap() };

        seed_pool(positions, core, FEE_A);
        seed_pool(positions, core, FEE_B);

        let buyback = deploy_autonomous_buyback(
            owner(),
            GlobalBuybackConfig {
                default_buy_token: addr(BUDOKAN),
                default_treasury: treasury(),
                default_minimum_amount: ONE,
                default_min_delay: 0,
                default_max_delay: 86400,
                default_min_duration: MIN_DURATION,
                default_max_duration: MAX_DURATION,
                default_fee: FEE_A,
            },
            addr(POSITIONS),
            addr(TWAMM),
        );
        let dispatcher = IBuybackDispatcher { contract_address: buyback };
        let admin = IBuybackAdminDispatcher { contract_address: buyback };

        let end_time = valid_end_time();

        // Order 0, at fee tier A
        whale_send(STRK, buyback, 2 * ONE);
        dispatcher.buy_back(BuybackParams { sell_token: addr(STRK), start_time: 0, end_time });
        let position_id = dispatcher.get_position_token_id(addr(STRK));
        assert(position_id != 0, 'Position minted');
        assert(dispatcher.get_config_epoch(addr(STRK)) == 0, 'Order 0 in epoch 0');

        // Correct the fee tier while order 0 is still open. This is the call the
        // old design refused outright with 'Fee mismatch'.
        start_cheat_caller_address(buyback, owner());
        admin
            .set_token_config(
                addr(STRK),
                Option::Some(
                    TokenBuybackConfig {
                        buy_token: addr(BUDOKAN),
                        treasury: treasury(),
                        minimum_amount: ONE,
                        min_delay: 0,
                        max_delay: 86400,
                        min_duration: MIN_DURATION,
                        max_duration: MAX_DURATION,
                        fee: FEE_B,
                    },
                ),
            );
        stop_cheat_caller_address(buyback);

        // Order 1, at fee tier B — a different Ekubo pool, same position
        whale_send(STRK, buyback, 2 * ONE);
        dispatcher.buy_back(BuybackParams { sell_token: addr(STRK), start_time: 0, end_time });

        assert(dispatcher.get_config_epoch(addr(STRK)) == 1, 'Fee change opened epoch 1');
        assert(dispatcher.get_order_count(addr(STRK)) == 2, 'Two orders');
        assert(dispatcher.get_position_token_id(addr(STRK)) == position_id, 'Same position reused');
        assert(dispatcher.get_order_info(addr(STRK), 0).fee == FEE_A, 'Order 0 keeps fee A');
        assert(dispatcher.get_order_info(addr(STRK), 1).fee == FEE_B, 'Order 1 has fee B');

        // Both orders run to completion
        start_cheat_block_timestamp_global(end_time + 1);

        let budokan = IERC20Dispatcher { contract_address: addr(BUDOKAN) };
        let before = budokan.balance_of(treasury());

        // Claimed ONE AT A TIME on purpose. A single batched claim would let a
        // wrong key on order 0 hide behind order 1's proceeds: the total would
        // still be non-zero and the bookmark would still reach 2. Per-order
        // claims make each key prove itself.
        let proceeds_0 = dispatcher.claim_buyback_proceeds(addr(STRK), 1);
        assert(dispatcher.get_order_bookmark(addr(STRK)) == 1, 'Order 0 claimed');
        assert(proceeds_0 > 0, 'Order 0 paid out under fee A');

        let proceeds_1 = dispatcher.claim_buyback_proceeds(addr(STRK), 1);
        assert(dispatcher.get_order_bookmark(addr(STRK)) == 2, 'Order 1 claimed');
        assert(proceeds_1 > 0, 'Order 1 paid out under fee B');

        let after = budokan.balance_of(treasury());
        stop_cheat_block_timestamp_global();

        // Each order was withdrawn against the key the component rebuilt from
        // its OWN epoch, and real BUDOKAN reached the treasury for both.
        assert(after - before == (proceeds_0 + proceeds_1).into(), 'Treasury got both payouts');
    }
}
