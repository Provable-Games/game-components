//! Alternative: Component-Level Toggle Pattern
//!
//! This shows how you could achieve similar functionality by making components themselves
//! toggleable rather than using the callback pattern.

use starknet::ContractAddress;

//================================================================================================
// MODE-BASED COMPONENT APPROACH
//================================================================================================

/// Component mode trait - defines enabled/disabled behavior
trait MinterMode<TContractState> {
    fn add_minter(ref self: ComponentState<TContractState>, minter_address: ContractAddress) -> u64;
    fn should_register_interface() -> bool;
    fn should_allocate_storage() -> bool;
}

/// Disabled mode - no-op implementations
impl DisabledMinterMode<TContractState> of MinterMode<TContractState> {
    fn add_minter(ref self: ComponentState<TContractState>, minter_address: ContractAddress) -> u64 {
        0 // No-op - feature disabled
    }
    
    fn should_register_interface() -> bool { 
        false // Don't register SRC5 interface
    }
    
    fn should_allocate_storage() -> bool { 
        false // Minimal storage allocation
    }
}

/// Enabled mode - full implementations
impl EnabledMinterMode<TContractState, +HasComponent<TContractState>, +Drop<TContractState>> of MinterMode<TContractState> {
    fn add_minter(ref self: ComponentState<TContractState>, minter_address: ContractAddress) -> u64 {
        // Full implementation
        let minter_count = self.minter_count.read();
        let minter_id = self.minter_registry.entry(minter_address).read();
        
        if minter_id == 0 {
            let new_id = minter_count + 1;
            self.minter_registry.entry(minter_address).write(new_id);
            self.minter_registry_id.entry(new_id).write(minter_address);
            self.minter_count.write(new_id);
            new_id
        } else {
            minter_id
        }
    }
    
    fn should_register_interface() -> bool { 
        true // Register SRC5 interface
    }
    
    fn should_allocate_storage() -> bool { 
        true // Full storage allocation
    }
}

//================================================================================================
// TOGGLEABLE MINTER COMPONENT
//================================================================================================

#[starknet::component]
pub mod ToggleableMinterComponent {
    use super::*;
    use starknet::storage::{StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use openzeppelin_introspection::src5::SRC5Component;

    #[storage]
    pub struct Storage {
        minter_registry: Map<ContractAddress, u64>,
        minter_registry_id: Map<u64, ContractAddress>,
        minter_count: u64,
        // Storage is always allocated, but might not be used if disabled
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(ToggleableMinterImpl)]
    impl ToggleableMinter<
        TContractState,
        +HasComponent<TContractState>,
        impl Mode: MinterMode<TContractState>, // MODE TRAIT BOUND
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMinter<ComponentState<TContractState>> {
        fn add_minter(ref self: ComponentState<TContractState>, minter_address: ContractAddress) -> u64 {
            Mode::add_minter(ref self, minter_address) // Delegate to mode
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Mode: MinterMode<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            if Mode::should_register_interface() {
                let mut src5_component = get_dep_component_mut!(ref self, SRC5);
                src5_component.register_interface(IMINIGAME_TOKEN_MINTER_ID);
            }
            // Only initialize storage if enabled
            if Mode::should_allocate_storage() {
                self.minter_count.write(0);
            }
        }
    }
}

//================================================================================================
// USAGE IN CONTRACT
//================================================================================================

#[starknet::contract]
pub mod ToggleableTokenContract {
    use super::*;
    use game_components_token::token::TokenComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;

    // ALWAYS include the component
    component!(path: ToggleableMinterComponent, storage: minter, event: MinterEvent);
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Toggle by changing the mode implementation
    #[abi(embed_v0)]
    impl MinterImpl = ToggleableMinterComponent::ToggleableMinter<
        ContractState,
        impl Mode: EnabledMinterMode<ContractState>, // ✅ ENABLED
        // impl Mode: DisabledMinterMode<ContractState>, // ❌ DISABLED
        impl SRC5: SRC5Component::HasComponent<ContractState>,
    >;

    // Token component still uses callback pattern (for comparison)
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::Token<
        ContractState,
        impl SRC5: SRC5Component::HasComponent<ContractState>,
        impl ERC721: ERC721Component::HasComponent<ContractState>,
        impl MinterCallback: SimpleTokenMinterCallback, // Direct integration
        impl ContextCallback: DefaultTokenContextCallback<ContractState>,
        // ... other callbacks
    >;

    // Simple callback that calls the toggleable component
    impl SimpleTokenMinterCallback of TokenMinterCallback<ContractState> {
        fn on_mint_with_minter(ref self: ContractState, minter_address: ContractAddress) -> u64 {
            self.minter.add_minter(minter_address) // Calls toggleable component
        }
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        minter: ToggleableMinterComponent::Storage,
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MinterEvent: ToggleableMinterComponent::Event,
        #[flat]
        TokenEvent: TokenComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, /* ... */) {
        // Components are always initialized
        self.minter.initializer(); // But behavior depends on mode
        self.token.initializer(Option::None);
        self.erc721.initializer("Test".into(), "TEST".into(), "".into());
    }
}

//================================================================================================
// COMPARISON: COMPONENT-LEVEL vs CALLBACK PATTERN
//================================================================================================

/*
COMPONENT-LEVEL TOGGLE PATTERN:
✅ Consistent architecture (all contracts have same components)
✅ Single source of truth (component controls its own behavior)
✅ Could be runtime configurable (with additional logic)
✅ Simpler TokenComponent (fewer trait bounds)

❌ Storage overhead (disabled components still allocate storage)
❌ Gas costs (component initialization still happens)
❌ Interface pollution (might still register interfaces)
❌ Less flexible (harder to customize per contract)

CALLBACK PATTERN (current):
✅ Zero overhead (no component = no cost)
✅ Highly flexible (easy to customize per contract) 
✅ Compile-time optimization (disabled features eliminated)
✅ Clean separation of concerns

❌ More complex trait bounds
❌ Requires understanding callback pattern
❌ Multiple moving parts

RECOMMENDATION:
- Use CALLBACK PATTERN for performance-critical applications (gaming)
- Use COMPONENT-LEVEL for standardized contract architectures
*/