/// PrizeExtensionComponent provides extensible prize logic for any context.
/// This component allows external contracts to implement custom prize deposit,
/// claim validation, payout modification, and ERC721 dynamic generation hooks.

#[starknet::component]
pub mod PrizeExtensionComponent {
    use game_components_interfaces::prize_extension::{IPRIZE_EXTENSION_ID, IPrizeExtension};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        owner_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    /// Internal trait that implementors must provide.
    /// This trait defines the prize logic that each extension implements.
    pub trait PrizeExtension<TContractState> {
        /// Called when a prize is deposited
        fn on_deposit(
            ref self: TContractState,
            context_id: u64,
            prize_id: u64,
            sponsor: ContractAddress,
            token_address: ContractAddress,
            amount_or_token_id: u128,
            is_erc721: bool,
            config: Span<felt252>,
        );

        /// Validate whether a claim should be allowed
        fn validate_claim(
            self: @TContractState,
            context_id: u64,
            prize_id: u64,
            claimer: ContractAddress,
            position: Option<u32>,
            config: Span<felt252>,
        ) -> bool;

        /// Called before payout - can modify amount. Returns (should_proceed, adjusted_amount)
        fn before_payout(
            ref self: TContractState,
            context_id: u64,
            prize_id: u64,
            recipient: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) -> (bool, u128);

        /// Called after payout is complete
        fn after_payout(
            ref self: TContractState,
            context_id: u64,
            prize_id: u64,
            recipient: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        );

        /// Generate a dynamic ERC721 prize token ID
        fn generate_erc721_prize(
            ref self: TContractState,
            context_id: u64,
            prize_id: u64,
            recipient: ContractAddress,
            base_token_id: u128,
            config: Span<felt252>,
        ) -> u128;

        /// Add configuration for a context
        fn add_config(ref self: TContractState, context_id: u64, config: Span<felt252>);
    }

    #[embeddable_as(PrizeExtensionImpl)]
    impl PrizeExtensionComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +PrizeExtension<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IPrizeExtension<ComponentState<TContractState>> {
        fn owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn on_deposit(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            sponsor: ContractAddress,
            token_address: ContractAddress,
            amount_or_token_id: u128,
            is_erc721: bool,
            config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            PrizeExtension::on_deposit(
                ref contract,
                context_id,
                prize_id,
                sponsor,
                token_address,
                amount_or_token_id,
                is_erc721,
                config,
            );
        }

        fn validate_claim(
            self: @ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            claimer: ContractAddress,
            position: Option<u32>,
            config: Span<felt252>,
        ) -> bool {
            let contract = self.get_contract();
            PrizeExtension::validate_claim(
                contract, context_id, prize_id, claimer, position, config,
            )
        }

        fn before_payout(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            recipient: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) -> (bool, u128) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            PrizeExtension::before_payout(
                ref contract, context_id, prize_id, recipient, amount, config,
            )
        }

        fn after_payout(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            recipient: ContractAddress,
            amount: u128,
            config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            PrizeExtension::after_payout(
                ref contract, context_id, prize_id, recipient, amount, config,
            );
        }

        fn generate_erc721_prize(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            prize_id: u64,
            recipient: ContractAddress,
            base_token_id: u128,
            config: Span<felt252>,
        ) -> u128 {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            PrizeExtension::generate_erc721_prize(
                ref contract, context_id, prize_id, recipient, base_token_id, config,
            )
        }

        fn add_config(
            ref self: ComponentState<TContractState>, context_id: u64, config: Span<felt252>,
        ) {
            self.assert_only_owner();
            let mut contract = self.get_contract_mut();
            PrizeExtension::add_config(ref contract, context_id, config);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, owner_address: ContractAddress) {
            self.owner_address.write(owner_address);

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IPRIZE_EXTENSION_ID);
        }

        fn get_owner_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner_address.read()
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            assert!(
                get_caller_address() == self.owner_address.read(),
                "Prize Extension: Only owner can call",
            );
        }
    }
}
