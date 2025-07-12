#[starknet::component]
pub mod TokenObjectivesComponent {
    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
    };

    use crate::extensions::objectives::interface::{
        IMINIGAME_TOKEN_OBJECTIVES_ID, IMinigameTokenObjectives,
    };
    use crate::extensions::objectives::structs::TokenObjective;

    use game_components_minigame::extensions::objectives::structs::GameObjective;

    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;

    #[storage]
    pub struct Storage {
        token_objective_count: Map<u64, u32>, // storage of the number of objectives for a token
        token_objectives: Map<
            (u64, u32), TokenObjective,
        > // storage of objective by token id and index
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ObjectiveCreated: ObjectiveCreated,
        ObjectiveCompleted: ObjectiveCompleted,
        AllObjectivesCompleted: AllObjectivesCompleted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCreated {
        pub game_address: ContractAddress,
        pub objective_id: u32,
        pub objective_data: GameObjective,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ObjectiveCompleted {
        pub token_id: u64,
        pub objective_id: u32,
        pub objective_index: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AllObjectivesCompleted {
        pub token_id: u64,
    }

    #[embeddable_as(TokenObjectivesImpl)]
    impl TokenObjectives<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IMinigameTokenObjectives<ComponentState<TContractState>> {
        fn objectives_count(self: @ComponentState<TContractState>, token_id: u64) -> u32 {
            self.token_objective_count.entry(token_id).read()
        }

        fn objectives(
            self: @ComponentState<TContractState>, token_id: u64,
        ) -> Array<TokenObjective> {
            let count = self.token_objective_count.entry(token_id).read();
            let mut objectives = ArrayTrait::new();
            let mut index = 0;

            while index < count {
                let objective = self.token_objectives.entry((token_id, index)).read();
                objectives.append(objective);
                index += 1;
            };

            objectives
        }

        fn objective_ids(self: @ComponentState<TContractState>, token_id: u64) -> Span<u32> {
            let count = self.token_objective_count.entry(token_id).read();
            let mut objective_ids = ArrayTrait::new();
            let mut index = 0;

            while index < count {
                let objective = self.token_objectives.entry((token_id, index)).read();
                objective_ids.append(objective.objective_id);
                index += 1;
            };

            objective_ids.span()
        }

        fn all_objectives_completed(self: @ComponentState<TContractState>, token_id: u64) -> bool {
            let total_count = self.token_objective_count.entry(token_id).read();
            let mut index = 0;
            let mut completed_count = 0;

            while index < total_count {
                let objective = self.token_objectives.entry((token_id, index)).read();
                if objective.completed {
                    completed_count += 1;
                }
                index += 1;
            };

            total_count == completed_count
        }

        fn create_objective(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            objective_id: u32,
            objective_data: GameObjective,
        ) {
            self.emit(ObjectiveCreated { game_address, objective_id, objective_data });
        }
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
            src5_component.register_interface(IMINIGAME_TOKEN_OBJECTIVES_ID);
        }

        fn get_objective(
            self: @ComponentState<TContractState>, token_id: u64, objective_index: u32,
        ) -> TokenObjective {
            self.token_objectives.entry((token_id, objective_index)).read()
        }

        fn set_objective(
            ref self: ComponentState<TContractState>,
            token_id: u64,
            objective_index: u32,
            objective: TokenObjective,
        ) {
            self.token_objectives.entry((token_id, objective_index)).write(objective);
        }
    }
}
