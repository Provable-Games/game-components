/// Holds a single ERC20 (received by plain transfer) and releases each deposit
/// to a beneficiary after a fixed term. Every arrival keeps its own term.
///
/// `lock` is the permissionless crank: it stamps whatever arrived since the
/// last call (`balance - locked_total`) with an unlock time. Unlock times round
/// UP to a day and same-day deposits merge, so records are bounded by
/// `lock_duration` in days (dust can't inflate `release`), and a deposit is
/// always held for at least the full term.
///
/// Token and `lock_duration` are fixed at `initializer` and have no setters.
/// `beneficiary` is the only mutable field (owner-gated by the embedder); it
/// redirects future funds, never shortens a lock. No emergency withdrawal.
/// `set_beneficiary` has no access check here — the embedder gates it via
/// `IDepositLockAdmin` (see the `DepositLock` preset).
#[starknet::component]
pub mod DepositLockComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::tokenomics::deposit_lock::IDepositLock;
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address};

    pub const SECONDS_PER_DAY: u64 = 86400;
    /// Convenience term: 365 days.
    pub const ONE_YEAR: u64 = 365 * SECONDS_PER_DAY;

    pub mod Errors {
        pub const ZERO_TOKEN: felt252 = 'Token cannot be zero';
        pub const ZERO_BENEFICIARY: felt252 = 'Beneficiary cannot be zero';
        pub const ZERO_DURATION: felt252 = 'Lock duration cannot be zero';
        pub const NOTHING_TO_LOCK: felt252 = 'Nothing to lock';
        pub const NOTHING_TO_RELEASE: felt252 = 'Nothing matured to release';
        pub const ZERO_LIMIT: felt252 = 'Limit must be non-zero';
        pub const TRANSFER_FAILED: felt252 = 'Token transfer failed';
    }

    #[storage]
    pub struct Storage {
        DepositLock_token: ContractAddress,
        DepositLock_beneficiary: ContractAddress,
        DepositLock_lock_duration: u64,
        DepositLock_locked_total: u256,
        /// unlock_day -> amount maturing that day.
        DepositLock_bucket: Map<u64, u256>,
        /// FIFO of days holding an amount; non-decreasing, so ordered by maturity.
        DepositLock_days: Map<u32, u64>,
        DepositLock_head: u32,
        DepositLock_tail: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Locked: Locked,
        Released: Released,
        BeneficiaryUpdated: BeneficiaryUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Locked {
        #[key]
        pub unlock_day: u64,
        pub amount: u256,
        pub unlock_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Released {
        #[key]
        pub beneficiary: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BeneficiaryUpdated {
        #[key]
        pub beneficiary: ContractAddress,
    }

    #[embeddable_as(DepositLockImpl)]
    pub impl DepositLock<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IDepositLock<ComponentState<TContractState>> {
        fn lock(ref self: ComponentState<TContractState>) -> u256 {
            let amount = self.pending();
            assert(amount > 0, Errors::NOTHING_TO_LOCK);

            let unlock_at = get_block_timestamp() + self.DepositLock_lock_duration.read();
            let unlock_day = (unlock_at + SECONDS_PER_DAY - 1) / SECONDS_PER_DAY;

            let tail = self.DepositLock_tail.read();
            let head = self.DepositLock_head.read();
            // Merge into the newest bucket iff same day (it can't have been released).
            let same_day = tail > head
                && self.DepositLock_days.entry(tail - 1).read() == unlock_day;
            if !same_day {
                self.DepositLock_days.entry(tail).write(unlock_day);
                self.DepositLock_tail.write(tail + 1);
            }

            self
                .DepositLock_bucket
                .entry(unlock_day)
                .write(self.DepositLock_bucket.entry(unlock_day).read() + amount);
            self.DepositLock_locked_total.write(self.DepositLock_locked_total.read() + amount);
            self.emit(Locked { unlock_day, amount, unlock_at });
            amount
        }

        fn release(ref self: ComponentState<TContractState>, limit: u32) -> u256 {
            assert(limit > 0, Errors::ZERO_LIMIT);
            let today = get_block_timestamp() / SECONDS_PER_DAY;
            let tail = self.DepositLock_tail.read();
            let mut head = self.DepositLock_head.read();
            let mut total: u256 = 0;
            let mut steps: u32 = 0;

            while head < tail && steps < limit {
                let day = self.DepositLock_days.entry(head).read();
                if day > today {
                    break;
                }
                total += self.DepositLock_bucket.entry(day).read();
                self.DepositLock_bucket.entry(day).write(0);
                head += 1;
                steps += 1;
            }

            assert(total > 0, Errors::NOTHING_TO_RELEASE);
            self.DepositLock_head.write(head);
            self.DepositLock_locked_total.write(self.DepositLock_locked_total.read() - total);

            let beneficiary = self.DepositLock_beneficiary.read();
            let erc20 = IERC20Dispatcher { contract_address: self.DepositLock_token.read() };
            assert(erc20.transfer(beneficiary, total), Errors::TRANSFER_FAILED);
            self.emit(Released { beneficiary, amount: total });
            total
        }

        fn pending(self: @ComponentState<TContractState>) -> u256 {
            let erc20 = IERC20Dispatcher { contract_address: self.DepositLock_token.read() };
            erc20.balance_of(get_contract_address()) - self.DepositLock_locked_total.read()
        }

        fn releasable(self: @ComponentState<TContractState>) -> u256 {
            let today = get_block_timestamp() / SECONDS_PER_DAY;
            let tail = self.DepositLock_tail.read();
            let mut head = self.DepositLock_head.read();
            let mut total: u256 = 0;
            while head < tail {
                let day = self.DepositLock_days.entry(head).read();
                if day > today {
                    break;
                }
                total += self.DepositLock_bucket.entry(day).read();
                head += 1;
            }
            total
        }

        fn locked_total(self: @ComponentState<TContractState>) -> u256 {
            self.DepositLock_locked_total.read()
        }

        fn unlock_day_at(self: @ComponentState<TContractState>, index: u32) -> (u64, u256) {
            let day = self.DepositLock_days.entry(index).read();
            (day, self.DepositLock_bucket.entry(day).read())
        }

        fn queue_range(self: @ComponentState<TContractState>) -> (u32, u32) {
            (self.DepositLock_head.read(), self.DepositLock_tail.read())
        }

        fn token(self: @ComponentState<TContractState>) -> ContractAddress {
            self.DepositLock_token.read()
        }

        fn beneficiary(self: @ComponentState<TContractState>) -> ContractAddress {
            self.DepositLock_beneficiary.read()
        }

        fn lock_duration(self: @ComponentState<TContractState>) -> u64 {
            self.DepositLock_lock_duration.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Set token, term (both fixed hereafter) and initial beneficiary.
        fn initializer(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            beneficiary: ContractAddress,
            lock_duration: u64,
        ) {
            assert(token.is_non_zero(), Errors::ZERO_TOKEN);
            assert(beneficiary.is_non_zero(), Errors::ZERO_BENEFICIARY);
            assert(lock_duration > 0, Errors::ZERO_DURATION);
            self.DepositLock_token.write(token);
            self.DepositLock_beneficiary.write(beneficiary);
            self.DepositLock_lock_duration.write(lock_duration);
            self.emit(BeneficiaryUpdated { beneficiary });
        }

        /// Redirect future funds. NO access check — the embedder gates it.
        fn set_beneficiary(ref self: ComponentState<TContractState>, beneficiary: ContractAddress) {
            assert(beneficiary.is_non_zero(), Errors::ZERO_BENEFICIARY);
            self.DepositLock_beneficiary.write(beneficiary);
            self.emit(BeneficiaryUpdated { beneficiary });
        }
    }
}
