/// Tests for the order record's storage packing.
///
/// The packing is hand-written, so a mistake corrupts every stored order and
/// only surfaces as a failed claim later — after funds are already in a TWAMM
/// position. These check the round trip at the BOUNDARIES rather than one
/// happy value, because that is where a bad shift or mask shows up.
#[cfg(test)]
mod order_packing_tests {
    use game_components_interfaces::tokenomics::buyback::{MAX_ORDER_AMOUNT, PackedOrderInfo};
    use starknet::Store;
    use starknet::storage_access::StorePacking;

    fn roundtrip(v: PackedOrderInfo) {
        let packed = StorePacking::<PackedOrderInfo, felt252>::pack(v);
        let out = StorePacking::<PackedOrderInfo, felt252>::unpack(packed);
        assert(out.start_time == v.start_time, 'start_time lost');
        assert(out.end_time == v.end_time, 'end_time lost');
        assert(out.amount == v.amount, 'amount lost');
    }

    /// The point of the change. Was 3 under the plain derive.
    #[test]
    fn occupies_one_storage_slot() {
        assert(Store::<PackedOrderInfo>::size() == 1, Store::<PackedOrderInfo>::size().into());
    }

    #[test]
    fn roundtrips_a_typical_order() {
        roundtrip(
            PackedOrderInfo { start_time: 0, end_time: 1788025088, amount: 3000000000000000000 },
        );
    }

    /// Every field at its maximum at once — where a bad shift bleeds one field
    /// into the next.
    #[test]
    fn roundtrips_at_the_boundaries() {
        roundtrip(
            PackedOrderInfo {
                start_time: 0xFFFFFFFFFFFFFFFF,
                end_time: 0xFFFFFFFFFFFFFFFF,
                amount: MAX_ORDER_AMOUNT,
            },
        );
    }

    #[test]
    fn roundtrips_all_zeros() {
        roundtrip(PackedOrderInfo { start_time: 0, end_time: 0, amount: 0 });
    }

    /// start and end are adjacent in the felt: a value in one must not appear
    /// in the other.
    #[test]
    fn does_not_bleed_between_adjacent_fields() {
        roundtrip(PackedOrderInfo { start_time: 0xFFFFFFFFFFFFFFFF, end_time: 0, amount: 0 });
        roundtrip(PackedOrderInfo { start_time: 0, end_time: 0xFFFFFFFFFFFFFFFF, amount: 0 });
        roundtrip(PackedOrderInfo { start_time: 0, end_time: 0, amount: MAX_ORDER_AMOUNT });
    }

    /// One over the cap must be refused, not silently wrapped.
    #[test]
    #[should_panic(expected: 'Order amount too large')]
    fn rejects_an_amount_that_would_truncate() {
        StorePacking::<
            PackedOrderInfo, felt252,
        >::pack(PackedOrderInfo { start_time: 0, end_time: 1, amount: MAX_ORDER_AMOUNT + 1 });
    }
}
