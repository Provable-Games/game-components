#[starknet::interface]
pub trait IObjectivesComponent<TState> {
    fn set_objectives(ref self: TState, token_id: u64, objective_ids: Span<u32>);
    fn get_objective(self: @TState, token_id: u64, objective_index: u32) -> TokenObjective;
    fn complete_objective(ref self: TState, token_id: u64, objective_index: u32);
    fn get_objectives_count(self: @TState, token_id: u64) -> u32;
    fn get_all_objectives(self: @TState, token_id: u64) -> Array<TokenObjective>;
    fn get_completed_objectives_count(self: @TState, token_id: u64) -> u32;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenObjective {
    pub objective_id: u32,
    pub completed: bool,
}

#[starknet::component]
pub mod ObjectivesComponent {
    use starknet::{ContractAddress, get_block_timestamp};
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };
    use crate::core::traits::OptionalObjectives;
    use super::{IObjectivesComponent, TokenObjective};

    #[storage]
    pub struct Storage {
        token_objectives: Map<u64, Map<u32, TokenObjective>>,
        token_objectives_count: Map<u64, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ObjectiveSet: ObjectiveSet,
        ObjectiveCompleted: ObjectiveCompleted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveSet {
        token_id: u64,
        objective_id: u32,
        game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCompleted {
        token_id: u64,
        objective_id: u32,
        completion_timestamp: u64,
    }

    #[embeddable_as(ObjectivesImpl)]
    pub impl Objectives<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IObjectivesComponent<ComponentState<TContractState>> {
        
        fn set_objectives(ref self: ComponentState<TContractState>, token_id: u64, objective_ids: Span<u32>) {
            let mut i = 0;
            while i < objective_ids.len() {
                let objective_id = *objective_ids.at(i);
                let objective = TokenObjective {
                    objective_id,
                    completed: false,
                };
                
                self.token_objectives.entry(token_id).entry(i).write(objective);
                
                self.emit(ObjectiveSet {
                    token_id,
                    objective_id,
                    game_address: starknet::contract_address_const::<0>(),
                });
                
                i += 1;
            };
            
            self.token_objectives_count.entry(token_id).write(objective_ids.len());
        }

        fn get_objective(self: @ComponentState<TContractState>, token_id: u64, objective_index: u32) -> TokenObjective {
            self.token_objectives.entry(token_id).entry(objective_index).read()
        }

        fn complete_objective(ref self: ComponentState<TContractState>, token_id: u64, objective_index: u32) {
            let mut objective = self.token_objectives.entry(token_id).entry(objective_index).read();
            
            objective.completed = true;
            
            self.token_objectives.entry(token_id).entry(objective_index).write(objective);
            
            self.emit(ObjectiveCompleted {
                token_id,
                objective_id: objective.objective_id,
                completion_timestamp: starknet::get_block_timestamp(),
            });
        }

        fn get_objectives_count(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            self.token_objectives_count.entry(token_id).read()
        }

        fn get_all_objectives(self: @ComponentState<TContractState>, token_id: u64) -> Array<TokenObjective> {
            let mut objectives = ArrayTrait::new();
            let count = self.token_objectives_count.entry(token_id).read();
            
            let mut i = 0;
            while i < count {
                let objective = self.token_objectives.entry(token_id).entry(i).read();
                objectives.append(objective);
                i += 1;
            };
            
            objectives
        }

        fn get_completed_objectives_count(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            let count = self.token_objectives_count.entry(token_id).read();
            let mut completed = 0;
            
            let mut i = 0;
            while i < count {
                let objective = self.token_objectives.entry(token_id).entry(i).read();
                if objective.completed {
                    completed += 1;
                }
                i += 1;
            };
            
            completed
        }
    }

    // Implementation of the OptionalObjectives trait for integration with CoreTokenComponent
    pub impl ObjectivesOptionalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of OptionalObjectives<TContractState> {
        
        fn set_token_objectives(ref self: TContractState, token_id: u64, objective_ids: Span<u32>) {
            let mut component = HasComponent::get_component_mut(ref self);
            component.set_objectives(token_id, objective_ids);
        }

        fn get_token_objectives_count(self: @TContractState, token_id: u64) -> u32 {
            let component = HasComponent::get_component(self);
            component.get_objectives_count(token_id)
        }

        fn are_objectives_completed(self: @TContractState, token_id: u64) -> bool {
            let component = HasComponent::get_component(self);
            let total = component.get_objectives_count(token_id);
            let completed = component.get_completed_objectives_count(token_id);
            total > 0 && completed == total
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(ref self: ComponentState<TContractState>) {
            // Nothing to initialize for objectives
        }
    }
} 