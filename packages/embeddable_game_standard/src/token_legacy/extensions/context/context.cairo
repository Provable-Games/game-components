#[starknet::component]
pub mod ContextComponent {
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use openzeppelin_introspection::src5::SRC5Component::{self, InternalTrait as SRC5InternalTrait};
    use starknet::ContractAddress;
    use crate::token_legacy::extensions::context::interface::IMINIGAME_TOKEN_CONTEXT_ID;
    use crate::token_legacy::traits::OptionalContext;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    pub impl ContextOptionalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of OptionalContext<TContractState> {
        fn on_context_set(
            ref self: TContractState,
            caller: ContractAddress,
            token_id: felt252,
            context: GameContextDetails,
        ) {}
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMINIGAME_TOKEN_CONTEXT_ID);
        }
    }
}
