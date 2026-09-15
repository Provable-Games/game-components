/// Tests for the order record's storage packing.
///
/// The packing is hand-written, so a mistake corrupts every stored order and
/// only surfaces as a failed claim later — after funds are already in a TWAMM
/// position. These check the round trip at the BOUNDARIES rather than one
/// happy value, because that is where a bad shift or mask shows up.
#[cfg(test)]
mod order_packing_tests {
    use game_components_interfaces::tokenomics::buyback::{
        MAX_CONFIG_EPOCH, MAX_ORDER_AMOUNT, MAX_ORDER_TIME, PackedOrderInfo,
    };
    use starknet::Store;
    use starknet::storage_access::StorePacking;

    fn roundtrip(v: PackedOrderInfo) {
        let packed = StorePacking::<PackedOrderInfo, felt252>::pack(v);
        let out = StorePacking::<PackedOrderInfo, felt252>::unpack(packed);
        assert(out.start_time == v.start_time, 'start_time lost');
        assert(out.end_time == v.end_time, 'end_time lost');
        assert(out.amount == v.amount, 'amount lost');
        assert(out.epoch == v.epoch, 'epoch lost');
    }

    /// The point of the change. Four fields, still one slot.
    #[test]
    fn occupies_one_storage_slot() {
        assert(Store::<PackedOrderInfo>::size() == 1, Store::<PackedOrderInfo>::size().into());
    }

    #[test]
    fn roundtrips_a_typical_order() {
        roundtrip(
            PackedOrderInfo {
                start_time: 0, end_time: 1788025088, amount: 3000000000000000000, epoch: 0,
            },
        );
    }

    /// Every field at its maximum at once — where a bad shift bleeds one field
    /// into the next.
    #[test]
    fn roundtrips_at_the_boundaries() {
        roundtrip(
            PackedOrderInfo {
                start_time: MAX_ORDER_TIME,
                end_time: MAX_ORDER_TIME,
                amount: MAX_ORDER_AMOUNT,
                epoch: MAX_CONFIG_EPOCH,
            },
        );
    }

    #[test]
    fn roundtrips_all_zeros() {
        roundtrip(PackedOrderInfo { start_time: 0, end_time: 0, amount: 0, epoch: 0 });
    }

    /// Adjacent fields must not bleed into each other: a value in one must not
    /// appear in the next. `epoch` sits in the top 10 bits, directly above
    /// `amount`, so a missing mask on the amount read shows up here.
    #[test]
    fn does_not_bleed_between_adjacent_fields() {
        roundtrip(PackedOrderInfo { start_time: MAX_ORDER_TIME, end_time: 0, amount: 0, epoch: 0 });
        roundtrip(PackedOrderInfo { start_time: 0, end_time: MAX_ORDER_TIME, amount: 0, epoch: 0 });
        roundtrip(
            PackedOrderInfo { start_time: 0, end_time: 0, amount: MAX_ORDER_AMOUNT, epoch: 0 },
        );
        roundtrip(
            PackedOrderInfo { start_time: 0, end_time: 0, amount: 0, epoch: MAX_CONFIG_EPOCH },
        );
    }

    /// A full-width amount alongside a non-zero epoch. If `unpack` read the
    /// amount without masking off the epoch bits, this is where it would come
    /// back wrong rather than merely large.
    #[test]
    fn epoch_does_not_leak_into_a_full_amount() {
        roundtrip(
            PackedOrderInfo {
                start_time: 1, end_time: 2, amount: MAX_ORDER_AMOUNT, epoch: MAX_CONFIG_EPOCH,
            },
        );
        roundtrip(
            PackedOrderInfo { start_time: 1, end_time: 2, amount: MAX_ORDER_AMOUNT, epoch: 1 },
        );
    }

    #[test]
    #[fuzzer(runs: 256)]
    fn roundtrips_arbitrary_fields(start_time: u64, end_time: u64, amount: u128, epoch: u16) {
        roundtrip(
            PackedOrderInfo {
                start_time: start_time & MAX_ORDER_TIME,
                end_time: end_time & MAX_ORDER_TIME,
                amount,
                epoch: epoch & MAX_CONFIG_EPOCH,
            },
        );
    }

    /// Fix the encoding independently of the roundtrip, including field offsets.
    #[test]
    fn layout_matches_218_bit_encoding() {
        let packed = StorePacking::<
            PackedOrderInfo, felt252,
        >::pack(
            PackedOrderInfo {
                start_time: MAX_ORDER_TIME,
                end_time: MAX_ORDER_TIME,
                amount: MAX_ORDER_AMOUNT,
                epoch: MAX_CONFIG_EPOCH,
            },
        );
        assert(
            packed == 0x3ffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            'Wrong packed maximum',
        );
        let packed = StorePacking::<
            PackedOrderInfo, felt252,
        >::pack(PackedOrderInfo { start_time: 1, end_time: 1, amount: 1, epoch: 1 });
        assert(
            packed == 0x10000000000000000000000000000000100000000010000000001,
            'Wrong field offsets',
        );
    }

    /// Future fields in the reserved high bits must not bleed into the epoch.
    #[test]
    #[fuzzer(runs: 256)]
    fn reserved_bits_do_not_change_existing_fields(reserved: u64) {
        let order = PackedOrderInfo {
            start_time: MAX_ORDER_TIME,
            end_time: MAX_ORDER_TIME,
            amount: MAX_ORDER_AMOUNT,
            epoch: MAX_CONFIG_EPOCH,
        };
        let packed = StorePacking::<PackedOrderInfo, felt252>::pack(order);
        let reserved: felt252 = (reserved & 0x1ffffffff).into();
        let extended = packed
            + reserved * 0x4000000000000000000000000000000000000000000000000000000;
        let decoded = StorePacking::<PackedOrderInfo, felt252>::unpack(extended);
        assert(decoded == order, 'Reserved bits leaked');
    }

    #[test]
    #[should_panic(expected: 'Order time too large')]
    fn rejects_start_time_overflow() {
        StorePacking::<
            PackedOrderInfo, felt252,
        >::pack(
            PackedOrderInfo { start_time: MAX_ORDER_TIME + 1, end_time: 0, amount: 0, epoch: 0 },
        );
    }

    #[test]
    #[should_panic(expected: 'Order time too large')]
    fn rejects_end_time_overflow() {
        StorePacking::<
            PackedOrderInfo, felt252,
        >::pack(
            PackedOrderInfo { start_time: 0, end_time: MAX_ORDER_TIME + 1, amount: 0, epoch: 0 },
        );
    }

    #[test]
    #[should_panic(expected: 'Config epochs exhausted')]
    fn rejects_epoch_overflow() {
        StorePacking::<
            PackedOrderInfo, felt252,
        >::pack(
            PackedOrderInfo { start_time: 0, end_time: 0, amount: 0, epoch: MAX_CONFIG_EPOCH + 1 },
        );
    }
}
