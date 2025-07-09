use starknet::ContractAddress;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
use game_components_metagame::extensions::context::structs::GameContextDetails;

// Token Hooks Trait - contracts must implement this
pub trait TokenHooksTrait<TContractState> {
    fn before_mint(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        objective_ids: Option<Span<u32>>,
        player_name: Option<ByteArray>,
        start: Option<u64>,
        end: Option<u64>,
        context: Option<GameContextDetails>,
        soulbound: bool,
    );
    
    fn after_mint(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        caller_address: ContractAddress,
    );
    
    fn before_update_game(
        ref self: TContractState,
        token_id: u64,
    );
    
    fn after_update_game(
        ref self: TContractState,
        token_id: u64,
        game_over: bool,
        completed_all_objectives: bool,
    );
}

// Empty implementation for minimal contracts
#[generate_trait]
pub impl TokenHooksEmptyImpl<TContractState> of TokenHooksTrait<TContractState> {
    fn before_mint(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        objective_ids: Option<Span<u32>>,
        player_name: Option<ByteArray>,
        start: Option<u64>,
        end: Option<u64>,
        context: Option<GameContextDetails>,
        soulbound: bool,
    ) {}
    
    fn after_mint(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        caller_address: ContractAddress,
    ) {}
    
    fn before_update_game(
        ref self: TContractState,
        token_id: u64,
    ) {}
    
    fn after_update_game(
        ref self: TContractState,
        token_id: u64,
        game_over: bool,
        completed_all_objectives: bool,
    ) {}
}

// Hook implementation with all features
#[generate_trait]
pub impl TokenHooksFullFeatured<
    TContractState,
    impl Minter: crate::extensions::minter::minter::MinterComponent::HasComponent<TContractState>,
    impl MultiGame: crate::extensions::multi_game::multi_game::MultiGameComponent::HasComponent<TContractState>,
    impl TokenObjectives: crate::extensions::objectives::objectives::TokenObjectivesComponent::HasComponent<TContractState>,
    impl SRC5: openzeppelin_introspection::src5::SRC5Component::HasComponent<TContractState>,
> of TokenHooksTrait<TContractState> {
    fn before_mint(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        objective_ids: Option<Span<u32>>,
        player_name: Option<ByteArray>,
        start: Option<u64>,
        end: Option<u64>,
        context: Option<GameContextDetails>,
        soulbound: bool,
    ) {
        use crate::extensions::multi_game::multi_game::MultiGameComponent::InternalTrait as MultiGameInternalTrait;
        
        // MultiGame validation
        if let Option::Some(game_address) = game_address {
            let multi_game = get_dep_component_mut!(ref self, MultiGame);
            let game_id = multi_game.get_game_id_from_address(game_address);
            assert(game_id != 0, 'Game not registered');
        }
    }
    
    fn after_mint(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        caller_address: ContractAddress,
    ) {
        use crate::extensions::multi_game::multi_game::MultiGameComponent::InternalTrait as MultiGameInternalTrait;
        use crate::extensions::minter::minter::MinterComponent::InternalTrait as MinterInternalTrait;
        use crate::extensions::objectives::objectives::TokenObjectivesComponent::InternalTrait as TokenObjectivesInternalTrait;
        use crate::extensions::objectives::structs::TokenObjective;
        
        // MultiGame: Store game ID if applicable
        if let Option::Some(game_address) = game_address {
            let mut multi_game = get_dep_component_mut!(ref self, MultiGame);
            let game_id = multi_game.get_game_id_from_address(game_address);
            // Store token's game ID - this would need to be added to multi_game component
            // For now, we'll skip this as it needs component modification
        }
        
        // Minter: Register minter with original caller preserved
        let mut minter = get_dep_component_mut!(ref self, Minter);
        let minted_by = minter.add_minter(caller_address);
        // The minter component should handle storing the minter address for the token
        
        // Objectives: Store if provided
        // Note: This requires updating the objectives component to handle initial objective storage
    }
    
    fn before_update_game(
        ref self: TContractState,
        token_id: u64,
    ) {
        // No pre-update logic needed for current features
    }
    
    fn after_update_game(
        ref self: TContractState,
        token_id: u64,
        game_over: bool,
        completed_all_objectives: bool,
    ) {
        // Could emit additional events or update component state if needed
    }
}