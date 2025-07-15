// Generic Event Relayer for Dojo
// This contract can relay any type of event data without knowing the specific structure

use starknet::ContractAddress;
use core::array::ArrayTrait;
use core::serde::Serde;

// Interface for the generic event relayer
#[starknet::interface]
trait IGenericEventRelayer<TContractState> {
    /// Initialize the relayer with a token address
    fn initialize(
        ref self: TContractState, 
        token_address: ContractAddress, 
        world_owner: ContractAddress
    );
    
    /// Emit a generic event with type and data
    fn emit_event(
        ref self: TContractState,
        event_type: felt252,
        event_data: Span<felt252>
    );
    
    /// Emit multiple events in a single call (batching)
    fn emit_event_batch(
        ref self: TContractState,
        events: Span<EventData>
    );
}

#[derive(Drop, Serde)]
struct EventData {
    event_type: felt252,
    timestamp: u64,
    data: Array<felt252>,
}

// Constants for event types
mod EventTypes {
    // Core token events
    const TOKEN_MINTED: felt252 = 'TokenMinted';
    const GAME_UPDATED: felt252 = 'GameUpdated';
    const SCORE_UPDATE: felt252 = 'ScoreUpdate';
    const METADATA_UPDATE: felt252 = 'MetadataUpdate';
    const TOKEN_METADATA_UPDATE: felt252 = 'TokenMetadataUpdate';
    const TOKEN_COUNTER_UPDATE: felt252 = 'TokenCounterUpdate';
    const PLAYER_NAME_UPDATE: felt252 = 'PlayerNameUpdate';
    const GAME_ADDRESS_UPDATE: felt252 = 'GameAddressUpdate';
    const GAME_REGISTRY_UPDATE: felt252 = 'GameRegistryUpdate';
    const EVENT_RELAYER_UPDATE: felt252 = 'EventRelayerUpdate';
    
    // Extension events
    const OBJECTIVE_SET: felt252 = 'ObjectiveSet';
    const OBJECTIVE_COMPLETED: felt252 = 'ObjectiveCompleted';
    const ALL_OBJECTIVES_COMPLETED: felt252 = 'AllObjectivesCompleted';
    const TOKEN_RENDERER_UPDATE: felt252 = 'TokenRendererUpdate';
    const MINTER_ADDED: felt252 = 'MinterAdded';
    const MINTER_COUNTER_UPDATE: felt252 = 'MinterCounterUpdate';
}

#[dojo::contract]
mod GenericEventRelayer {
    use super::{IGenericEventRelayer, EventData, EventTypes};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use core::num::traits::Zero;

    // Model to track token addresses
    #[derive(Copy, Drop, Serde)]
    #[dojo::model]
    struct TokenAddress {
        #[key]
        version: felt252,
        token_address: ContractAddress,
    }

    const DEFAULT_NS: felt252 = 'game_components';
    const VERSION: felt252 = '0.0.1';

    #[storage]
    struct Storage {
        admin_address: ContractAddress,
    }

    // Generic event that can represent any event type
    #[derive(Drop, Serde)]
    #[dojo::event]
    pub struct GenericEvent {
        #[key]
        pub event_type: felt252,
        #[key]
        pub timestamp: u64,
        pub caller: ContractAddress,
        pub data_len: u32,
        pub data: Span<felt252>,
    }

    #[abi(embed_v0)]
    impl GenericEventRelayerImpl of IGenericEventRelayer<ContractState> {
        fn initialize(
            ref self: ContractState, 
            token_address: ContractAddress, 
            world_owner: ContractAddress
        ) {
            let caller = get_caller_address();
            
            // First time initialization - set the world owner
            if self.admin_address.read().is_zero() {
                self.admin_address.write(world_owner);
            }
            
            // Check if caller is the world owner
            assert!(self.admin_address.read() == caller, "Only admin can initialize");
            
            // Store the token address
            let mut world = self.world(@DEFAULT_NS);
            let mut storage: WorldStorage = world;
            storage.write_model(@TokenAddress { 
                version: VERSION, 
                token_address: token_address 
            });
        }

        fn emit_event(
            ref self: ContractState,
            event_type: felt252,
            event_data: Span<felt252>
        ) {
            self.validate_caller();
            
            let mut world = self.world(@DEFAULT_NS);
            let timestamp = get_block_timestamp();
            let caller = get_caller_address();
            
            world.emit_event(@GenericEvent {
                event_type,
                timestamp,
                caller,
                data_len: event_data.len(),
                data: event_data,
            });
        }

        fn emit_event_batch(
            ref self: ContractState,
            events: Span<EventData>
        ) {
            self.validate_caller();
            
            let mut world = self.world(@DEFAULT_NS);
            let caller = get_caller_address();
            
            // Emit each event in the batch
            let mut i = 0;
            while i < events.len() {
                let event = events.at(i);
                world.emit_event(@GenericEvent {
                    event_type: event.event_type,
                    timestamp: event.timestamp,
                    caller,
                    data_len: event.data.len(),
                    data: event.data.span(),
                });
                i += 1;
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn validate_caller(ref self: ContractState) {
            let mut world = self.world(@DEFAULT_NS);
            let storage: WorldStorage = world;
            let caller = get_caller_address();
            let token_address_model: TokenAddress = storage.read_model(VERSION);
            assert!(token_address_model.token_address == caller, "Invalid caller");
        }
    }
}

// ===== SIMPLIFIED INTEGRATION WITH CORE TOKEN =====
// 
// Instead of the current pattern with 15+ conditional checks:
//
// Before (current implementation):
// ```
// if let Option::Some(relayer) = self.get_event_relayer() {
//     relayer.emit_token_metadata_update(
//         token_id,
//         metadata.game_id,
//         metadata.minted_at,
//         metadata.settings_id,
//         metadata.lifecycle.start,
//         metadata.lifecycle.end,
//         metadata.minted_by,
//         metadata.soulbound,
//         metadata.game_over,
//         metadata.completed_all_objectives,
//         metadata.has_context,
//         metadata.objectives_count,
//     );
// }
// ```
//
// After (with generic relayer):
// ```
// self.emit_to_relayer(EventTypes::TOKEN_METADATA_UPDATE, metadata);
// ```

// Helper trait for CoreTokenComponent
trait EventRelayerHelper<TContractState> {
    /// Emit any serializable data to the event relayer
    fn emit_to_relayer<T: Serde<T> + Drop>(
        ref self: TContractState,
        event_type: felt252,
        data: T
    );
    
    /// Batch emit multiple events
    fn emit_batch_to_relayer(
        ref self: TContractState,
        events: Array<EventData>
    );
}

// Example implementation for CoreTokenComponent
// This would be added to CoreTokenComponent:
/*
impl EventRelayerHelperImpl of EventRelayerHelper<ComponentState<TContractState>> {
    fn emit_to_relayer<T: Serde<T> + Drop>(
        ref self: ComponentState<TContractState>,
        event_type: felt252,
        data: T
    ) {
        if let Option::Some(relayer_addr) = self.event_relayer_address.read() {
            if !relayer_addr.is_zero() {
                let mut serialized = array![];
                data.serialize(ref serialized);
                
                IGenericEventRelayerDispatcher { 
                    contract_address: relayer_addr 
                }.emit_event(event_type, serialized.span());
            }
        }
    }
    
    fn emit_batch_to_relayer(
        ref self: ComponentState<TContractState>,
        events: Array<EventData>
    ) {
        if let Option::Some(relayer_addr) = self.event_relayer_address.read() {
            if !relayer_addr.is_zero() {
                IGenericEventRelayerDispatcher { 
                    contract_address: relayer_addr 
                }.emit_event_batch(events.span());
            }
        }
    }
}
*/

// ===== BENEFITS OF THIS APPROACH =====
//
// 1. **Reduced Code**: From 15+ conditional blocks to a single helper call
// 2. **Type Safety**: Still maintains type safety through Serde
// 3. **Flexibility**: Can add new event types without modifying the relayer
// 4. **Gas Efficiency**: Supports batching for multiple events
// 5. **Simpler Maintenance**: One generic contract instead of specific methods
// 6. **Easier Testing**: Mock a single emit_event method
//
// ===== MIGRATION EXAMPLE =====
//
// Current mint function has 6 separate relayer calls.
// With the new approach:
//
// ```
// fn mint(...) -> u64 {
//     let mut events = array![];
//     
//     // ... mint logic ...
//     
//     // Collect all events
//     if minted_by > 0 {
//         events.append(EventData {
//             event_type: EventTypes::MINTER_ADDED,
//             timestamp: get_block_timestamp(),
//             data: array![minted_by.into(), caller.into()],
//         });
//     }
//     
//     // Emit all events in one call
//     self.emit_batch_to_relayer(events);
// }
// ```