/// Divides whatever it receives across a weighted list of destinations.
///
/// `distribute` reads the contract's own balance of a token and pays each leg
/// its basis-point share, with the FINAL leg taking the remainder — so the
/// parts always sum to exactly the whole and integer division strands no dust.
/// Permissionless, and needs no per-token setup (any ERC20 works).
///
/// The split is fixed at `initializer`: no setter, no owner. Redirecting the
/// revenue source to a different splitter is the only way to change a ratio,
/// which makes the split structure rather than mutable policy. There is no
/// emergency withdrawal — `distribute` is the only way funds leave, and it is
/// permissionless.
///
/// Standard-ERC20 assumption: a token reporting a balance ≥ `2^256 / 10000`
/// overflows the `total * bps` multiply (a single-leg split avoids it), and a
/// non-standard `transfer` (no return value, or fee-on-transfer) reverts
/// `distribute` for that token. Neither arises for a well-behaved ERC20.
#[starknet::component]
pub mod SplitterComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::tokenomics::splitter::{ISplitter, SplitLeg};
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_contract_address};

    /// Basis-point denominator. A split must sum to exactly this.
    pub const BPS_DENOMINATOR: u16 = 10000;
    /// Leg-count bound, so `distribute`'s loop is always cheap.
    pub const MAX_LEGS: u32 = 8;

    pub mod Errors {
        pub const EMPTY_SPLIT: felt252 = 'Split must have >= 1 leg';
        pub const TOO_MANY_LEGS: felt252 = 'Too many legs';
        pub const BPS_SUM: felt252 = 'Split must sum to 10000 bps';
        pub const ZERO_BPS: felt252 = 'Leg bps must be non-zero';
        pub const ZERO_DESTINATION: felt252 = 'Destination cannot be zero';
        pub const DUPLICATE_DESTINATION: felt252 = 'Duplicate destination';
        pub const NOTHING_TO_DISTRIBUTE: felt252 = 'No balance to distribute';
        pub const TRANSFER_FAILED: felt252 = 'Token transfer failed';
        pub const ZERO_TOKEN: felt252 = 'Token cannot be zero';
    }

    /// Storage keys prefixed `Splitter_` to avoid collisions. Cairo storage
    /// cannot hold a `Span`, so the split is a length plus an indexed map.
    #[storage]
    pub struct Storage {
        Splitter_split_len: u32,
        Splitter_split: Map<u32, SplitLeg>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SplitConfigured: SplitConfigured,
        Distributed: Distributed,
        LegPaid: LegPaid,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SplitConfigured {
        pub legs: Span<SplitLeg>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Distributed {
        #[key]
        pub token: ContractAddress,
        pub total: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LegPaid {
        #[key]
        pub token: ContractAddress,
        #[key]
        pub destination: ContractAddress,
        pub amount: u256,
    }

    #[embeddable_as(SplitterImpl)]
    pub impl Splitter<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of ISplitter<ComponentState<TContractState>> {
        fn distribute(ref self: ComponentState<TContractState>, token: ContractAddress) -> u256 {
            assert(token.is_non_zero(), Errors::ZERO_TOKEN);
            let total = IERC20Dispatcher { contract_address: token }
                .balance_of(get_contract_address());
            assert(total > 0, Errors::NOTHING_TO_DISTRIBUTE);
            self._distribute(token, total)
        }

        fn distribute_many(
            ref self: ComponentState<TContractState>, tokens: Span<ContractAddress>,
        ) {
            let mut i: u32 = 0;
            while i < tokens.len() {
                let token = *tokens.at(i);
                assert(token.is_non_zero(), Errors::ZERO_TOKEN);
                // Skip empty tokens rather than reverting the whole batch (the
                // intended caller is a keeper sweeping a fixed token list).
                // Single-token `distribute` still reverts on an empty balance.
                let total = IERC20Dispatcher { contract_address: token }
                    .balance_of(get_contract_address());
                if total > 0 {
                    self._distribute(token, total);
                }
                i += 1;
            }
        }

        fn split(self: @ComponentState<TContractState>) -> Span<SplitLeg> {
            let len = self.Splitter_split_len.read();
            let mut out: Array<SplitLeg> = array![];
            let mut i: u32 = 0;
            while i < len {
                out.append(self.Splitter_split.entry(i).read());
                i += 1;
            }
            out.span()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Validate and store the split. Legs must be non-empty, ≤ `MAX_LEGS`,
        /// each with a non-zero destination and bps, no duplicate destination,
        /// summing to exactly `BPS_DENOMINATOR`. No setter exposes this again.
        fn initializer(ref self: ComponentState<TContractState>, legs: Span<SplitLeg>) {
            assert(legs.len() > 0, Errors::EMPTY_SPLIT);
            assert(legs.len() <= MAX_LEGS, Errors::TOO_MANY_LEGS);

            let mut sum: u32 = 0;
            let mut i: u32 = 0;
            while i < legs.len() {
                let leg = *legs.at(i);
                assert(leg.destination.is_non_zero(), Errors::ZERO_DESTINATION);
                assert(leg.bps > 0, Errors::ZERO_BPS);
                let mut k: u32 = 0;
                while k < i {
                    assert(
                        (*legs.at(k)).destination != leg.destination, Errors::DUPLICATE_DESTINATION,
                    );
                    k += 1;
                }
                sum += leg.bps.into();
                i += 1;
            }
            assert(sum == BPS_DENOMINATOR.into(), Errors::BPS_SUM);

            let mut j: u32 = 0;
            while j < legs.len() {
                self.Splitter_split.entry(j).write(*legs.at(j));
                j += 1;
            }
            self.Splitter_split_len.write(legs.len());
            self.emit(SplitConfigured { legs });
        }

        /// Split `total` (already read from `token`) across the legs. The final
        /// leg takes the remainder, so `paid` never exceeds `total` and no dust
        /// is stranded.
        fn _distribute(
            ref self: ComponentState<TContractState>, token: ContractAddress, total: u256,
        ) -> u256 {
            let erc20 = IERC20Dispatcher { contract_address: token };
            let len = self.Splitter_split_len.read();
            let mut paid: u256 = 0;
            let mut i: u32 = 0;
            while i < len {
                let leg = self.Splitter_split.entry(i).read();
                let amount = if i == len - 1 {
                    total - paid
                } else {
                    (total * leg.bps.into()) / BPS_DENOMINATOR.into()
                };
                paid += amount;
                if amount > 0 {
                    // ERC20 may report failure by returning false; assert it.
                    assert(erc20.transfer(leg.destination, amount), Errors::TRANSFER_FAILED);
                    self.emit(LegPaid { token, destination: leg.destination, amount });
                }
                i += 1;
            }
            self.emit(Distributed { token, total });
            total
        }
    }
}
