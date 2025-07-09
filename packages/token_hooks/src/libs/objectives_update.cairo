// Library for handling objectives updates in token hooks
pub mod objectives_update {
    use starknet::ContractAddress;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent::InternalTrait;
    use crate::extensions::objectives::objectives::TokenObjectivesComponent::InternalImpl;
    use crate::extensions::objectives::structs::TokenObjective;
    use game_components_minigame::interface::{IMinigameDispatcher, IMinigameDispatcherTrait};
    use game_components_minigame::extensions::objectives::interface::{
        IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait, IMINIGAME_OBJECTIVES_ID
    };
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    
    /// Processes objectives for a token and returns whether all objectives are completed
    /// 
    /// This function:
    /// 1. Gets objectives from the game
    /// 2. Updates each objective's completion status
    /// 3. Returns true if all objectives are completed
    /// 
    /// Note: Assumes the contract supports objectives if called
    pub fn process_token_objectives<
        TContractState,
        +TokenObjectivesComponent::HasComponent<TContractState>,
        +openzeppelin_introspection::src5::SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    >(
        ref contract: TContractState,
        token_id: u64,
        game_address: ContractAddress,
        objectives_count: u32,
    ) -> bool {
        if objectives_count == 0 {
            return false;
        }
        
        // Validate game supports objectives
        let game_src5_dispatcher = ISRC5Dispatcher { contract_address: game_address };
        assert!(
            game_src5_dispatcher.supports_interface(IMINIGAME_OBJECTIVES_ID),
            "MinigameToken: Game does not support objectives"
        );
        
        // Get objectives component
        let mut objectives_component = TokenObjectivesComponent::HasComponent::<TContractState>::get_component_mut(ref contract);
        
        // Get objectives address from game
        let minigame_dispatcher = IMinigameDispatcher { contract_address: game_address };
        let objectives_address = minigame_dispatcher.objectives_address();
        
        // Validate objectives contract supports interface
        let objectives_src5_dispatcher = ISRC5Dispatcher { contract_address: objectives_address };
        assert!(
            objectives_src5_dispatcher.supports_interface(IMINIGAME_OBJECTIVES_ID),
            "MinigameToken: Objectives contract does not support IMinigameObjectives"
        );
        
        let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address: objectives_address };
        
        // Check each objective
        let mut completed_count = 0;
        let mut i: u32 = 0;
        
        loop {
            if i >= objectives_count {
                break;
            }
            
            // Get objective from storage
            let objective = objectives_component.get_objective(token_id, i);
            
            // Check if completed in game
            let is_completed = objectives_dispatcher.completed_objective(token_id, objective.objective_id);
            
            if is_completed && !objective.completed {
                // Update objective as completed
                let updated_objective = TokenObjective {
                    objective_id: objective.objective_id,
                    completed: true,
                };
                objectives_component.set_objective(token_id, i, updated_objective);
            }
            
            if is_completed {
                completed_count += 1;
            }
            
            i += 1;
        };
        
        // Return true if all objectives completed
        completed_count == objectives_count
    }
    
    /// Simplified version for contracts that don't have TokenObjectivesComponent
    /// Returns (game_over, completed_all_objectives) based on game state
    pub fn check_objectives_status(
        token_id: u64,
        game_address: ContractAddress,
        game_over: bool,
    ) -> (bool, bool) {
        if game_over {
            // Game is over, objectives don't matter
            return (true, false);
        }
        
        // For simplified version, just return game state
        // Developers can extend this for custom logic
        (game_over, false)
    }
}