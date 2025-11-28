//
// Context Component
//
#[starknet::component]
pub mod ContextComponent {
    use crate::extensions::context::interface::{IMetagameContext, IMETAGAME_CONTEXT_ID};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;

    #[storage]
    pub struct Storage {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +IMetagameContext<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            self.register_context_interface();
        }

        fn register_context_interface(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IMETAGAME_CONTEXT_ID);
        }
    }
}
