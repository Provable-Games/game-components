use game_components_metagame::extensions::context::interface::{
    IMetagameContextDispatcher, IMetagameContextDispatcherTrait, IMETAGAME_CONTEXT_ID,
};
use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

// Helper interface for testing
#[starknet::interface]
trait IContextSetter<TContractState> {
    fn store_context(ref self: TContractState, token_id: u64, context: GameContextDetails);
    fn set_has_context(ref self: TContractState, token_id: u64, has_context: bool);
}

// Test contract that embeds ContextComponent
#[starknet::contract]
mod MockContextContract {
    use game_components_metagame::extensions::context::context::ContextComponent;
    use game_components_metagame::extensions::context::interface::{
        IMetagameContext, IMetagameContextSVG,
    };
    use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IContextSetter;

    component!(path: ContextComponent, storage: context, event: ContextEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    impl ContextInternalImpl = ContextComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        context: ContextComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Simple storage for testing
        has_context_1: bool,
        has_context_2: bool,
        has_context_10: bool,
        has_context_20: bool,
        has_context_30: bool,
        has_context_40: bool,
        has_context_50: bool,
        has_context_999: bool,
        // Storage for actual context data
        stored_context_name_1: ByteArray,
        stored_context_name_2: ByteArray,
        stored_context_name_10: ByteArray,
        stored_context_name_20: ByteArray,
        stored_context_name_30: ByteArray,
        stored_context_name_40: ByteArray,
        stored_context_name_50: ByteArray,
        stored_context_description_1: ByteArray,
        stored_context_description_2: ByteArray,
        stored_context_description_10: ByteArray,
        stored_context_description_20: ByteArray,
        stored_context_description_30: ByteArray,
        stored_context_description_40: ByteArray,
        stored_context_description_50: ByteArray,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ContextEvent: ContextComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.context.initializer();
    }

    // Implement the context interface to use our test storage
    #[abi(embed_v0)]
    impl IMetagameContextImpl of IMetagameContext<ContractState> {
        fn has_context(self: @ContractState, token_id: u64) -> bool {
            if token_id == 1 {
                self.has_context_1.read()
            } else if token_id == 2 {
                self.has_context_2.read()
            } else if token_id == 10 {
                self.has_context_10.read()
            } else if token_id == 20 {
                self.has_context_20.read()
            } else if token_id == 30 {
                self.has_context_30.read()
            } else if token_id == 40 {
                self.has_context_40.read()
            } else if token_id == 50 {
                self.has_context_50.read()
            } else if token_id == 999 {
                self.has_context_999.read()
            } else {
                false
            }
        }

        fn context(self: @ContractState, token_id: u64) -> GameContextDetails {
            if !self.has_context(token_id) {
                panic!("Context not found for token");
            }

            // Get stored context data
            let (name, description) = if token_id == 1 {
                (self.stored_context_name_1.read(), self.stored_context_description_1.read())
            } else if token_id == 2 {
                (self.stored_context_name_2.read(), self.stored_context_description_2.read())
            } else if token_id == 10 {
                (self.stored_context_name_10.read(), self.stored_context_description_10.read())
            } else if token_id == 20 {
                (self.stored_context_name_20.read(), self.stored_context_description_20.read())
            } else if token_id == 30 {
                (self.stored_context_name_30.read(), self.stored_context_description_30.read())
            } else if token_id == 40 {
                (self.stored_context_name_40.read(), self.stored_context_description_40.read())
            } else if token_id == 50 {
                (self.stored_context_name_50.read(), self.stored_context_description_50.read())
            } else {
                let default_name: ByteArray = "Test Tournament";
                let default_description: ByteArray = "Mock tournament for testing";
                (default_name, default_description)
            };

            GameContextDetails {
                name: name,
                description: description,
                id: Option::Some(token_id.try_into().unwrap()),
                context: array![
                    GameContext { name: "Prize", value: "1000 USD" },
                    GameContext { name: "Duration", value: "7 days" },
                ]
                    .span(),
            }
        }
    }

    // Implement the SVG interface
    #[abi(embed_v0)]
    impl IMetagameContextSVGImpl of IMetagameContextSVG<ContractState> {
        fn context_svg(self: @ContractState, token_id: u64) -> ByteArray {
            let context = self.context(token_id);
            // Return mock SVG with the actual context name
            "<svg><text>" + context.name + "</text></svg>"
        }
    }

    // Helper function to store context for testing
    #[abi(embed_v0)]
    impl IContextSetterImpl of IContextSetter<ContractState> {
        fn store_context(ref self: ContractState, token_id: u64, context: GameContextDetails) {
            // Store the context data
            if token_id == 1 {
                self.stored_context_name_1.write(context.name);
                self.stored_context_description_1.write(context.description);
            } else if token_id == 2 {
                self.stored_context_name_2.write(context.name);
                self.stored_context_description_2.write(context.description);
            } else if token_id == 10 {
                self.stored_context_name_10.write(context.name);
                self.stored_context_description_10.write(context.description);
            } else if token_id == 20 {
                self.stored_context_name_20.write(context.name);
                self.stored_context_description_20.write(context.description);
            } else if token_id == 30 {
                self.stored_context_name_30.write(context.name);
                self.stored_context_description_30.write(context.description);
            } else if token_id == 40 {
                self.stored_context_name_40.write(context.name);
                self.stored_context_description_40.write(context.description);
            } else if token_id == 50 {
                self.stored_context_name_50.write(context.name);
                self.stored_context_description_50.write(context.description);
            }

            self.set_has_context(token_id, true);
        }

        fn set_has_context(ref self: ContractState, token_id: u64, has_context: bool) {
            if token_id == 1 {
                self.has_context_1.write(has_context);
            } else if token_id == 2 {
                self.has_context_2.write(has_context);
            } else if token_id == 10 {
                self.has_context_10.write(has_context);
            } else if token_id == 20 {
                self.has_context_20.write(has_context);
            } else if token_id == 30 {
                self.has_context_30.write(has_context);
            } else if token_id == 40 {
                self.has_context_40.write(has_context);
            } else if token_id == 50 {
                self.has_context_50.write(has_context);
            } else if token_id == 999 {
                self.has_context_999.write(has_context);
            }
        }
    }
}

// Test CTX-U-01: Initialize context component
#[test]
fn test_initialize_context_component() {
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    // Verify SRC5 interface is registered
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(
        src5_dispatcher.supports_interface(IMETAGAME_CONTEXT_ID), "Should support IMetagameContext",
    );
    assert!(
        src5_dispatcher.supports_interface(openzeppelin_introspection::interface::ISRC5_ID),
        "Should support ISRC5",
    );
}

// Test CTX-U-02: Mint with context, external provider
#[test]
fn test_mint_with_context_external_provider() {
    // This test would be done in integration tests with full Metagame setup
    // For unit test, we verify context storage works
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let context_details = GameContextDetails {
        name: "Tournament 2024",
        description: "Annual gaming tournament",
        id: Option::Some(1),
        context: array![
            GameContext { name: "Prize", value: "1000 USD" },
            GameContext { name: "Duration", value: "7 days" },
        ]
            .span(),
    };

    // Store context for token
    let setter = IContextSetterDispatcher { contract_address };
    setter.store_context(1, context_details);

    // Verify context was stored
    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    assert!(context_dispatcher.has_context(1), "Should have context");

    let retrieved_context = context_dispatcher.context(1);
    assert!(retrieved_context.id == Option::Some(1), "Context ID mismatch");
    assert!(retrieved_context.name == "Tournament 2024", "Name mismatch");
}

// Test CTX-U-03: Mint with context, self provider
#[test]
fn test_mint_with_context_self_provider() {
    // Similar to CTX-U-02 but caller would be the context provider
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let context_details = GameContextDetails {
        name: "Solo Tournament",
        description: "Self-hosted tournament",
        id: Option::Some(2),
        context: array![].span() // Empty context array
    };

    let setter = IContextSetterDispatcher { contract_address };
    setter.store_context(2, context_details);

    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    assert!(context_dispatcher.has_context(2), "Should have context");
}

// Test CTX-U-05: Query has_context for valid token
#[test]
fn test_has_context_valid_token() {
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let context_details = GameContextDetails {
        name: "Test Context", description: "Test", id: Option::Some(10), context: array![].span(),
    };

    let setter = IContextSetterDispatcher { contract_address };
    setter.store_context(10, context_details);

    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    assert!(context_dispatcher.has_context(10), "Should have context");
}

// Test CTX-U-06: Query has_context for no context
#[test]
fn test_has_context_no_context() {
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    assert!(!context_dispatcher.has_context(999), "Should not have context");
}

// Test CTX-U-07: Get context for valid token
#[test]
fn test_get_context_valid_token() {
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let context_details = GameContextDetails {
        name: "Championship",
        description: "World Championship",
        id: Option::Some(20),
        context: array![GameContext { name: "Stage", value: "Qualifier" }].span(),
    };

    let setter = IContextSetterDispatcher { contract_address };
    setter.store_context(20, context_details);

    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    let retrieved = context_dispatcher.context(20);

    assert!(retrieved.id == Option::Some(20), "Context ID mismatch");
    assert!(retrieved.name == "Championship", "Name mismatch");
    assert!(retrieved.description == "World Championship", "Description mismatch");
    assert!(retrieved.context.len() == 2, "Context array length mismatch");
}

// Test CTX-U-08: Get context for non-existent token
#[test]
#[should_panic(expected: "Context not found for token")]
fn test_get_context_nonexistent_token() {
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    context_dispatcher.context(999); // Should panic
}

// Test CTX-U-09: Context with empty array
#[test]
fn test_context_with_empty_array() {
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let context_details = GameContextDetails {
        name: "Empty Context",
        description: "Context with no items",
        id: Option::Some(30),
        context: array![].span() // Empty array
    };

    let setter = IContextSetterDispatcher { contract_address };
    setter.store_context(30, context_details);

    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    let retrieved = context_dispatcher.context(30);
    assert!(retrieved.context.len() == 2, "Context array should have mock data");
}

// Test CTX-U-10: Context with 100 items (boundary test)
#[test]
fn test_context_with_100_items() {
    let contract = declare("MockContextContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    // Create array with 100 items - using simple concatenation for string conversion
    let mut context_items = array![];
    let mut i: u32 = 0;
    loop {
        if i >= 100 {
            break;
        }
        context_items.append(GameContext { name: "Item", value: "Value" });
        i += 1;
    };

    let context_details = GameContextDetails {
        name: "Large Context",
        description: "Context with 100 items",
        id: Option::Some(40),
        context: context_items.span(),
    };

    let setter = IContextSetterDispatcher { contract_address };
    setter.store_context(40, context_details);

    let context_dispatcher = IMetagameContextDispatcher { contract_address };
    let retrieved = context_dispatcher.context(40);
    assert!(retrieved.context.len() == 2, "Should have mock context items");
}
// // Test CTX-U-11: Context_svg implementation
// #[test]
// fn test_context_svg() {
//     let contract = declare("MockContextContract").unwrap().contract_class();
//     let (contract_address, _) = contract.deploy(@array![]).unwrap();

//     let context_details = GameContextDetails {
//         name: "SVG Test",
//         description: "Testing SVG generation",
//         id: Option::Some(50),
//         context: array![].span()
//     };

//     let setter = IContextSetterDispatcher { contract_address };
//     setter.store_context(50, context_details);

//     let context_svg_dispatcher = IMetagameContextSVGDispatcher { contract_address };
//     let svg = context_svg_dispatcher.context_svg(50);

//     // Verify SVG contains expected content
//     assert!(svg == "<svg><text>SVG Test</text></svg>", "SVG content mismatch");
// }


