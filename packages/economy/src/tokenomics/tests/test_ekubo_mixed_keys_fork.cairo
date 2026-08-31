/// Does ONE Ekubo position hold orders under DIFFERENT order keys?
///
/// The config-epoch design rests on this. If a position NFT were bound to one
/// buy_token/fee pair, an order created after a config change would need its own
/// position, and letting the config move while orders are open would be far more
/// than a storage change.
///
/// Reading Ekubo says it does: a sale is keyed by (owner, salt, order_key), with
/// `salt` = the position id — `ITWAMM::get_order_info` takes all three, and
/// `Positions::increase_sell_amount` forwards `salt: id` alongside the key. But
/// reading is not running, so this exercises it against the real deployed Ekubo:
/// one position, two orders, two different FEE TIERS, i.e. two different pools.
#[cfg(test)]
mod ekubo_mixed_keys_fork_tests {
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use ekubo::interfaces::extensions::twamm::{ITWAMMDispatcher, ITWAMMDispatcherTrait, OrderKey};
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use ekubo::types::i129::i129;
    use ekubo::types::keys::PoolKey;
    use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use snforge_std::{load, start_cheat_caller_address, stop_cheat_caller_address};
    use starknet::{ContractAddress, get_block_timestamp};

    // Ekubo on Sepolia. NOT the mainnet addresses — those are not deployed there,
    // a difference that already produced one unusable pipeline deployment.
    const POSITIONS: felt252 = 0x06a2aee84bb0ed5dded4384ddd0e40e9c1372b818668375ab8e3ec08807417e5;
    const TWAMM: felt252 = 0x073ec792c33b52d5f96940c2860d512b3884f2127d25e023eb9d44a678e4b971;

    const STRK: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
    const BUDOKAN: felt252 = 0x00886cabf9da06823eabbe4e6e806384d2af66d7f33cd654a724f85348e5c286;
    /// Holds STRK on Sepolia at the forked block.
    const WHALE: felt252 = 0x48fde8afe1f0976568b411c75d5f65a9175189514f101132bcd524a96ae8648;

    /// 0.05% and 0.3%, as Ekubo's 128-bit fraction of one.
    const FEE_A: u128 = 170141183460469235273462165868118016;
    const FEE_B: u128 = 1020847100762815390390123822295304634;

    /// TWAMM pools always use the maximum tick spacing.
    const MAX_TICK_SPACING: u128 = 354892;

    const ONE_STRK: u128 = 1000000000000000000;

    fn addr(v: felt252) -> ContractAddress {
        v.try_into().unwrap()
    }

    /// Ekubo's time validity requires order boundaries on a coarse grid the
    /// further out they sit. 2**16 is the step our live orders use.
    fn valid_end_time() -> u64 {
        let step: u64 = 65536;
        ((get_block_timestamp() + 300000) / step + 1) * step
    }

    fn order_key(fee: u128, end_time: u64) -> OrderKey {
        OrderKey { sell_token: addr(STRK), buy_token: addr(BUDOKAN), fee, start_time: 0, end_time }
    }

    /// The pool an OrderKey resolves to: tokens sorted, the order's fee, max tick
    /// spacing, and the TWAMM extension.
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

    /// Move STRK into Positions, which is how a sale is funded: the caller
    /// transfers first, then Positions pays core out of its own balance.
    fn fund_positions(amount: u128) {
        let strk = IERC20Dispatcher { contract_address: addr(STRK) };
        start_cheat_caller_address(addr(STRK), addr(WHALE));
        strk.transfer(addr(POSITIONS), amount.into());
        stop_cheat_caller_address(addr(STRK));
    }

    #[test]
    #[fork("SEPOLIA")]
    fn one_position_holds_orders_at_two_fee_tiers() {
        let positions = IPositionsDispatcher { contract_address: addr(POSITIONS) };
        let twamm = ITWAMMDispatcher { contract_address: addr(TWAMM) };

        // Core is not a published constant for this network; read it out of the
        // Positions contract rather than hardcoding another address that might
        // be the wrong network's.
        let core_felt = *load(addr(POSITIONS), selector!("core"), 1).at(0);
        let core = ICoreDispatcher { contract_address: core_felt.try_into().unwrap() };

        // The second fee tier needs a pool to exist. Idempotent, so this is a
        // no-op if the pair already trades there.
        let _ = core.maybe_initialize_pool(pool_key_for(FEE_A), i129 { mag: 0, sign: false });
        let _ = core.maybe_initialize_pool(pool_key_for(FEE_B), i129 { mag: 0, sign: false });

        let end_time = valid_end_time();
        let key_a = order_key(FEE_A, end_time);
        let key_b = order_key(FEE_B, end_time);

        // Order 1 mints the position. The caller is NOT cheated here: core calls
        // back INTO Positions during the lock, and a caller cheat on Positions
        // hijacks that callback so its own core-only guard rejects it. The test
        // contract owns the position instead.
        fund_positions(ONE_STRK);
        let (id, sale_rate_a) = positions.mint_and_increase_sell_amount(key_a, ONE_STRK);
        assert(id != 0, 'Position minted');
        assert(sale_rate_a != 0, 'Order A has a sale rate');

        // Order 2: SAME position id, different fee — so a different pool.
        // Under a per-position config binding this is the call that would fail.
        fund_positions(ONE_STRK);
        let sale_rate_b = positions.increase_sell_amount(id, key_b, ONE_STRK);
        assert(sale_rate_b != 0, 'Order B has a sale rate');

        // Both sales exist independently under the one salt. Owner is Positions:
        // it is the address that locked core on our behalf.
        let info_a = twamm.get_order_info(addr(POSITIONS), id.into(), key_a);
        let info_b = twamm.get_order_info(addr(POSITIONS), id.into(), key_b);

        assert(info_a.sale_rate != 0, 'A still live after B');
        assert(info_b.sale_rate != 0, 'B live alongside A');
        assert(info_a.remaining_sell_amount != 0, 'A holds its own amount');
        assert(info_b.remaining_sell_amount != 0, 'B holds its own amount');
    }
}
