// SPDX-License-Identifier: BUSL-1.1

/// GPP (Guaranteed Prize Pool) Component
/// A reusable component for managing capacity-limited, per-entrant prize pools.
/// Supports ERC20 (fungible pool) and ERC721 (NFT stack) prize types.
/// Multiple contexts are supported via context_id.
#[starknet::component]
pub mod GppComponent {
    use core::num::traits::Zero;
    use game_components_interfaces::gpp::{
        GppConfig, GppERC20Prize, GppERC721Prize, GppPoolState, IGPP_ID, IGpp,
    };
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use crate::gpp::store::Store;
    use crate::gpp::structs::{
        PRIZE_TYPE_ERC20, PRIZE_TYPE_ERC721, PRIZE_TYPE_UNSET, PackedGppConfig, PackedGppPool,
    };

    #[storage]
    pub struct Storage {
        gpp_config: Map<u64, PackedGppConfig>,
        gpp_prize_token: Map<u64, ContractAddress>,
        gpp_pool: Map<u64, PackedGppPool>,
        gpp_nft_at: Map<(u64, u32), u128>,
        gpp_token_nft: Map<felt252, u128>,
        gpp_token_claimed: Map<(u64, felt252), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    // ==========================================================================
    // HOOKS TRAIT
    // ==========================================================================

    pub trait GppHooksTrait<TContractState> {
        /// Called after a prize pool is funded
        fn on_pool_funded(
            ref self: TContractState,
            context_id: u64,
            sponsor: ContractAddress,
            token_address: ContractAddress,
            prize_type: u8,
            funded_slots: u32,
        );

        /// Called after a slot is reserved for a game token
        fn on_slot_reserved(ref self: TContractState, context_id: u64, token_id: felt252);

        /// Called after a slot is released (completion or expiry)
        fn on_slot_released(
            ref self: TContractState, context_id: u64, token_id: felt252, reason: felt252,
        );

        /// Called after a prize is claimed
        fn on_prize_claimed(
            ref self: TContractState,
            context_id: u64,
            token_id: felt252,
            recipient: ContractAddress,
            prize_type: u8,
            amount: u128,
            nft_token_id: u128,
        );
    }

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_config(self: @ComponentState<TContractState>, context_id: u64) -> PackedGppConfig {
            self.gpp_config.read(context_id)
        }

        fn set_config(
            ref self: ComponentState<TContractState>, context_id: u64, config: PackedGppConfig,
        ) {
            self.gpp_config.write(context_id, config);
        }

        fn get_prize_token(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> ContractAddress {
            self.gpp_prize_token.read(context_id)
        }

        fn set_prize_token(
            ref self: ComponentState<TContractState>, context_id: u64, addr: ContractAddress,
        ) {
            self.gpp_prize_token.write(context_id, addr);
        }

        fn get_pool(self: @ComponentState<TContractState>, context_id: u64) -> PackedGppPool {
            self.gpp_pool.read(context_id)
        }

        fn set_pool(
            ref self: ComponentState<TContractState>, context_id: u64, pool: PackedGppPool,
        ) {
            self.gpp_pool.write(context_id, pool);
        }

        fn get_nft_at(self: @ComponentState<TContractState>, context_id: u64, index: u32) -> u128 {
            self.gpp_nft_at.read((context_id, index))
        }

        fn set_nft_at(
            ref self: ComponentState<TContractState>, context_id: u64, index: u32, nft_id: u128,
        ) {
            self.gpp_nft_at.write((context_id, index), nft_id);
        }

        fn get_token_nft(self: @ComponentState<TContractState>, token_id: felt252) -> u128 {
            self.gpp_token_nft.read(token_id)
        }

        fn set_token_nft(
            ref self: ComponentState<TContractState>, token_id: felt252, nft_id: u128,
        ) {
            self.gpp_token_nft.write(token_id, nft_id);
        }

        fn is_claimed(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> bool {
            self.gpp_token_claimed.read((context_id, token_id))
        }

        fn set_claimed(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            token_id: felt252,
            claimed: bool,
        ) {
            self.gpp_token_claimed.write((context_id, token_id), claimed);
        }
    }

    // ==========================================================================
    // EMBEDDABLE VIEW INTERFACE
    // ==========================================================================

    #[embeddable_as(GppImpl)]
    impl GppView<
        TContractState,
        +HasComponent<TContractState>,
        +GppHooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IGpp<ComponentState<TContractState>> {
        fn get_gpp_config(self: @ComponentState<TContractState>, context_id: u64) -> GppConfig {
            let config = self.gpp_config.read(context_id);
            GppConfig { capacity: config.capacity, game_lifetime: config.game_lifetime }
        }

        fn get_gpp_pool_state(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> GppPoolState {
            let config = self.gpp_config.read(context_id);
            let pool = self.gpp_pool.read(context_id);
            let prize_token = self.gpp_prize_token.read(context_id);
            GppPoolState {
                pool_balance: pool.pool_balance,
                active_count: pool.active_count,
                nft_top: pool.nft_top,
                prize_type: config.prize_type,
                capacity: config.capacity,
                prize_token,
            }
        }

        fn get_gpp_active_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self.gpp_pool.read(context_id).active_count
        }

        fn get_gpp_funded_slots(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            let config = self.gpp_config.read(context_id);
            if config.prize_type == PRIZE_TYPE_ERC20 {
                let pool = self.gpp_pool.read(context_id);
                if config.per_entrant == 0 {
                    return 0;
                }
                (pool.pool_balance / config.per_entrant).try_into().unwrap()
            } else if config.prize_type == PRIZE_TYPE_ERC721 {
                self.gpp_pool.read(context_id).nft_top
            } else {
                0
            }
        }

        fn is_gpp_claimed(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> bool {
            self.gpp_token_claimed.read((context_id, token_id))
        }
    }

    // ==========================================================================
    // INTERNAL TRAIT
    // ==========================================================================

    #[generate_trait]
    pub impl GppInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +GppHooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of GppInternalTrait<TContractState> {
        /// Initialize the GPP component — registers SRC5 interface
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IGPP_ID);
        }

        /// Configure a new GPP context with capacity and game lifetime.
        /// Prize type and per_entrant are set on first fund call.
        fn _configure(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            capacity: u32,
            game_lifetime: u32,
        ) {
            assert!(capacity > 0, "ZERO_CAPACITY");
            assert!(game_lifetime > 0, "ZERO_GAME_LIFETIME");

            let config = PackedGppConfig {
                capacity, game_lifetime, prize_type: PRIZE_TYPE_UNSET, per_entrant: 0,
            };
            self.gpp_config.write(context_id, config);

            let pool = PackedGppPool { pool_balance: 0, active_count: 0, nft_top: 0 };
            self.gpp_pool.write(context_id, pool);
        }

        /// Fund an ERC20 prize pool. Anyone can sponsor.
        /// On first call: sets prize_type and per_entrant.
        /// On subsequent calls: validates consistency with first call.
        fn _fund_erc20(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            sponsor: ContractAddress,
            token_address: ContractAddress,
            erc20_prize: GppERC20Prize,
        ) {
            assert!(!token_address.is_zero(), "ZERO_TOKEN");
            assert!(erc20_prize.amount > 0, "ZERO_AMOUNT");
            assert!(erc20_prize.per_entrant > 0, "ZERO_PER_ENTRANT");
            assert!(erc20_prize.amount >= erc20_prize.per_entrant, "AMOUNT_BELOW_PER_ENTRANT");

            let mut config = self.gpp_config.read(context_id);

            if config.prize_type == PRIZE_TYPE_UNSET {
                config.prize_type = PRIZE_TYPE_ERC20;
                config.per_entrant = erc20_prize.per_entrant;
                self.gpp_config.write(context_id, config);
                self.gpp_prize_token.write(context_id, token_address);
            } else {
                assert!(config.prize_type == PRIZE_TYPE_ERC20, "PRIZE_TYPE_MISMATCH");
                assert!(self.gpp_prize_token.read(context_id) == token_address, "TOKEN_MISMATCH");
                assert!(config.per_entrant == erc20_prize.per_entrant, "PER_ENTRANT_MISMATCH");
            }

            // Transfer ERC20 and update pool
            let erc20 = IERC20Dispatcher { contract_address: token_address };
            let amount_u256: u256 = erc20_prize.amount.into();
            erc20.transfer_from(sponsor, starknet::get_contract_address(), amount_u256);

            let mut pool_state = self.gpp_pool.read(context_id);
            pool_state.pool_balance += erc20_prize.amount;
            self.gpp_pool.write(context_id, pool_state);

            let funded_slots: u32 = (pool_state.pool_balance / erc20_prize.per_entrant)
                .try_into()
                .unwrap();

            let mut contract = self.get_contract_mut();
            GppHooksTrait::on_pool_funded(
                ref contract, context_id, sponsor, token_address, PRIZE_TYPE_ERC20, funded_slots,
            );
        }

        /// Fund with an ERC721 NFT. Anyone can sponsor.
        /// On first call: sets prize_type.
        /// On subsequent calls: validates consistency.
        fn _fund_erc721(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            sponsor: ContractAddress,
            token_address: ContractAddress,
            erc721_prize: GppERC721Prize,
        ) {
            assert!(!token_address.is_zero(), "ZERO_TOKEN");

            let mut config = self.gpp_config.read(context_id);

            if config.prize_type == PRIZE_TYPE_UNSET {
                config.prize_type = PRIZE_TYPE_ERC721;
                self.gpp_config.write(context_id, config);
                self.gpp_prize_token.write(context_id, token_address);
            } else {
                assert!(config.prize_type == PRIZE_TYPE_ERC721, "PRIZE_TYPE_MISMATCH");
                assert!(self.gpp_prize_token.read(context_id) == token_address, "TOKEN_MISMATCH");
            }

            // Transfer NFT and push onto stack
            let erc721 = IERC721Dispatcher { contract_address: token_address };
            let nft_id_u256: u256 = erc721_prize.token_id.into();
            erc721.transfer_from(sponsor, starknet::get_contract_address(), nft_id_u256);

            let mut pool_state = self.gpp_pool.read(context_id);
            self.gpp_nft_at.write((context_id, pool_state.nft_top), erc721_prize.token_id);
            pool_state.nft_top += 1;
            self.gpp_pool.write(context_id, pool_state);

            let mut contract = self.get_contract_mut();
            GppHooksTrait::on_pool_funded(
                ref contract,
                context_id,
                sponsor,
                token_address,
                PRIZE_TYPE_ERC721,
                pool_state.nft_top,
            );
        }

        /// Reserve a slot for a game token on entry.
        /// Asserts capacity and funding, then reserves prize from pool.
        fn _reserve_slot(
            ref self: ComponentState<TContractState>, context_id: u64, game_token_id: felt252,
        ) {
            let config = self.gpp_config.read(context_id);
            assert!(config.prize_type != PRIZE_TYPE_UNSET, "NO_GPP_PRIZE");

            let mut pool_state = self.gpp_pool.read(context_id);
            assert!(pool_state.active_count < config.capacity, "SLOTS_FULL");

            pool_state.active_count += 1;

            if config.prize_type == PRIZE_TYPE_ERC20 {
                assert!(pool_state.pool_balance >= config.per_entrant, "POOL_DEPLETED");
                pool_state.pool_balance -= config.per_entrant;
            } else {
                assert!(pool_state.nft_top > 0, "POOL_DEPLETED");
                pool_state.nft_top -= 1;
                let nft_id = self.gpp_nft_at.read((context_id, pool_state.nft_top));
                self.gpp_token_nft.write(game_token_id, nft_id);
            }

            self.gpp_pool.write(context_id, pool_state);

            let mut contract = self.get_contract_mut();
            GppHooksTrait::on_slot_reserved(ref contract, context_id, game_token_id);
        }

        /// Mark a slot as completed — decrements active_count only.
        /// The reserved prize stays allocated for the player to claim via `_claim_prize`.
        fn _complete_slot(
            ref self: ComponentState<TContractState>, context_id: u64, game_token_id: felt252,
        ) {
            let mut pool_state = self.gpp_pool.read(context_id);
            pool_state.active_count -= 1;
            self.gpp_pool.write(context_id, pool_state);

            let mut contract = self.get_contract_mut();
            GppHooksTrait::on_slot_released(ref contract, context_id, game_token_id, 'completed');
        }

        /// Release a slot on expiry — decrements active_count AND returns reserved prize to pool.
        fn _release_slot(
            ref self: ComponentState<TContractState>, context_id: u64, game_token_id: felt252,
        ) {
            let config = self.gpp_config.read(context_id);
            let mut pool_state = self.gpp_pool.read(context_id);
            pool_state.active_count -= 1;

            if config.prize_type == PRIZE_TYPE_ERC20 {
                pool_state.pool_balance += config.per_entrant;
            } else {
                let nft_id = self.gpp_token_nft.read(game_token_id);
                self.gpp_nft_at.write((context_id, pool_state.nft_top), nft_id);
                pool_state.nft_top += 1;
            }

            self.gpp_pool.write(context_id, pool_state);

            let mut contract = self.get_contract_mut();
            GppHooksTrait::on_slot_released(ref contract, context_id, game_token_id, 'expired');
        }

        /// Claim reserved prize for a completed game token.
        /// Follows CEI: marks claimed BEFORE payout.
        fn _claim_prize(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            game_token_id: felt252,
            recipient: ContractAddress,
        ) {
            assert!(!self.gpp_token_claimed.read((context_id, game_token_id)), "ALREADY_CLAIMED");

            // CEI: mark claimed BEFORE payout
            self.gpp_token_claimed.write((context_id, game_token_id), true);

            let config = self.gpp_config.read(context_id);
            let prize_token = self.gpp_prize_token.read(context_id);

            let mut prize_amount: u128 = 0;
            let mut nft_token_id: u128 = 0;

            if config.prize_type == PRIZE_TYPE_ERC20 {
                prize_amount = config.per_entrant;
                let erc20 = IERC20Dispatcher { contract_address: prize_token };
                let amount_u256: u256 = config.per_entrant.into();
                erc20.transfer(recipient, amount_u256);
            } else {
                nft_token_id = self.gpp_token_nft.read(game_token_id);
                let erc721 = IERC721Dispatcher { contract_address: prize_token };
                let nft_u256: u256 = nft_token_id.into();
                erc721.transfer_from(starknet::get_contract_address(), recipient, nft_u256);
            }

            let mut contract = self.get_contract_mut();
            GppHooksTrait::on_prize_claimed(
                ref contract,
                context_id,
                game_token_id,
                recipient,
                config.prize_type,
                prize_amount,
                nft_token_id,
            );
        }

        /// Withdraw remaining ERC20 pool balance to recipient.
        fn _withdraw_erc20(
            ref self: ComponentState<TContractState>, context_id: u64, recipient: ContractAddress,
        ) {
            let config = self.gpp_config.read(context_id);
            assert!(config.prize_type == PRIZE_TYPE_ERC20, "NOT_ERC20");

            let mut pool_state = self.gpp_pool.read(context_id);
            assert!(pool_state.pool_balance > 0, "EMPTY_POOL");

            let balance = pool_state.pool_balance;
            pool_state.pool_balance = 0;
            self.gpp_pool.write(context_id, pool_state);

            let prize_token = self.gpp_prize_token.read(context_id);
            let erc20 = IERC20Dispatcher { contract_address: prize_token };
            let balance_u256: u256 = balance.into();
            erc20.transfer(recipient, balance_u256);
        }

        /// Withdraw remaining ERC721 NFTs from the stack.
        /// Returns the number of NFTs withdrawn.
        /// Pass limit=0 to withdraw all.
        fn _withdraw_erc721(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            recipient: ContractAddress,
            limit: u32,
        ) -> u32 {
            let config = self.gpp_config.read(context_id);
            assert!(config.prize_type == PRIZE_TYPE_ERC721, "NOT_ERC721");

            let mut pool_state = self.gpp_pool.read(context_id);
            assert!(pool_state.nft_top > 0, "EMPTY_POOL");

            let prize_token = self.gpp_prize_token.read(context_id);
            let erc721 = IERC721Dispatcher { contract_address: prize_token };
            let mut withdrawn: u32 = 0;

            while pool_state.nft_top > 0 && (limit == 0 || withdrawn < limit) {
                pool_state.nft_top -= 1;
                let nft_id = self.gpp_nft_at.read((context_id, pool_state.nft_top));
                let nft_u256: u256 = nft_id.into();
                erc721.transfer_from(starknet::get_contract_address(), recipient, nft_u256);
                withdrawn += 1;
            }

            self.gpp_pool.write(context_id, pool_state);
            withdrawn
        }

        // ── View helpers ──

        fn _get_config(self: @ComponentState<TContractState>, context_id: u64) -> PackedGppConfig {
            self.gpp_config.read(context_id)
        }

        fn _get_pool_state(
            self: @ComponentState<TContractState>, context_id: u64,
        ) -> PackedGppPool {
            self.gpp_pool.read(context_id)
        }

        fn _get_active_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self.gpp_pool.read(context_id).active_count
        }

        fn _get_funded_slots(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            let config = self.gpp_config.read(context_id);
            if config.prize_type == PRIZE_TYPE_ERC20 {
                let pool = self.gpp_pool.read(context_id);
                if config.per_entrant == 0 {
                    return 0;
                }
                (pool.pool_balance / config.per_entrant).try_into().unwrap()
            } else if config.prize_type == PRIZE_TYPE_ERC721 {
                self.gpp_pool.read(context_id).nft_top
            } else {
                0
            }
        }

        fn _is_claimed(
            self: @ComponentState<TContractState>, context_id: u64, game_token_id: felt252,
        ) -> bool {
            self.gpp_token_claimed.read((context_id, game_token_id))
        }
    }
}

// ==============================================================================
// EMPTY HOOKS IMPLEMENTATION
// ==============================================================================

pub impl GppHooksEmptyImpl<TContractState> of GppComponent::GppHooksTrait<TContractState> {
    fn on_pool_funded(
        ref self: TContractState,
        context_id: u64,
        sponsor: starknet::ContractAddress,
        token_address: starknet::ContractAddress,
        prize_type: u8,
        funded_slots: u32,
    ) {}

    fn on_slot_reserved(ref self: TContractState, context_id: u64, token_id: felt252) {}

    fn on_slot_released(
        ref self: TContractState, context_id: u64, token_id: felt252, reason: felt252,
    ) {}

    fn on_prize_claimed(
        ref self: TContractState,
        context_id: u64,
        token_id: felt252,
        recipient: starknet::ContractAddress,
        prize_type: u8,
        amount: u128,
        nft_token_id: u128,
    ) {}
}
