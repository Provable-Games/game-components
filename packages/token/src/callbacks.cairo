// Callback implementations for optional token features
//
// This file provides DEFAULT implementations (no-op, for features OFF)
// For features ON, projects should implement the callback traits manually in their contracts

use starknet::ContractAddress;
use game_components_metagame::extensions::context::structs::GameContextDetails;
use crate::extensions::multi_game::structs::GameMetadata;
use crate::extensions::objectives::structs::TokenObjective;
use crate::interface::{
    TokenMinterCallback, TokenContextCallback, TokenSoulboundCallback, TokenRendererCallback,
    TokenMultiGameCallback, TokenObjectivesCallback
};

//================================================================================================
// DEFAULT IMPLEMENTATIONS (NO-OP)
//================================================================================================

// Default implementation for minter - does nothing
pub impl DefaultTokenMinterCallback<TContractState, +Drop<TContractState>> of TokenMinterCallback<TContractState> {
    fn on_mint_with_minter(ref self: TContractState, minter_address: ContractAddress) -> u64 {
        0 // Default: no minter tracking
    }
}

// Default implementation for context - does nothing
pub impl DefaultTokenContextCallback<TContractState, +Drop<TContractState>> of TokenContextCallback<TContractState> {
    fn on_mint_with_context(ref self: TContractState, token_id: u64, context: GameContextDetails) {
        // Default: no context handling
    }
}

// Default implementation for soulbound - does nothing
pub impl DefaultTokenSoulboundCallback<TContractState, +Drop<TContractState>> of TokenSoulboundCallback<TContractState> {
    fn on_mint_soulbound(ref self: TContractState, token_id: u64, to: ContractAddress) {
        // Default: no soulbound handling
    }
}

// Default implementation for renderer - does nothing
pub impl DefaultTokenRendererCallback<TContractState, +Drop<TContractState>> of TokenRendererCallback<TContractState> {
    fn on_mint_with_renderer(ref self: TContractState, token_id: u64, renderer_address: ContractAddress) {
        // Default: no renderer handling
    }
}

// Default implementation for multi-game - panics since not supported
pub impl DefaultTokenMultiGameCallback<TContractState, +Drop<TContractState>> of TokenMultiGameCallback<TContractState> {
    fn get_game_id_from_address(ref self: TContractState, game_address: ContractAddress) -> u64 {
        panic!("Multi-game functionality not supported")
    }
    
    fn get_game_metadata(ref self: TContractState, game_id: u64) -> GameMetadata {
        panic!("Multi-game functionality not supported")
    }
    
    fn get_game_address_from_id(ref self: TContractState, game_id: u64) -> ContractAddress {
        panic!("Multi-game functionality not supported")
    }
}

// Default implementation for token objectives - panics since not supported
pub impl DefaultTokenObjectivesCallback<TContractState, +Drop<TContractState>> of TokenObjectivesCallback<TContractState> {
    fn get_objective(ref self: TContractState, token_id: u64, objective_index: u32) -> TokenObjective {
        panic!("Token objectives functionality not supported")
    }
    
    fn set_objective(ref self: TContractState, token_id: u64, objective_index: u32, objective: TokenObjective) {
        panic!("Token objectives functionality not supported")
    }
}

//================================================================================================
// MANUAL IMPLEMENTATION EXAMPLES
//================================================================================================
//
// For features ON, implement the callback traits manually in your contracts.
// Here are examples of how to implement them:
//
// Example: Minter tracking
// impl MinterCallback of TokenMinterCallback<ContractState> {
//     fn on_mint_with_minter(ref self: ContractState, minter_address: ContractAddress) -> u64 {
//         self.minter.add_minter(minter_address)
//     }
// }
//
// Example: Multi-game support  
// impl MultiGameCallback of TokenMultiGameCallback<ContractState> {
//     fn get_game_id_from_address(ref self: ContractState, game_address: ContractAddress) -> u64 {
//         self.multi_game.get_game_id_from_address(game_address)
//     }
//     
//     fn get_game_metadata(ref self: ContractState, game_id: u64) -> GameMetadata {
//         self.multi_game.get_game_metadata(game_id)
//     }
//     
//     fn get_game_address_from_id(ref self: ContractState, game_id: u64) -> ContractAddress {
//         self.multi_game.get_game_address_from_id(game_id)
//     }
// }
//
// Example: Token objectives
// impl ObjectivesCallback of TokenObjectivesCallback<ContractState> {
//     fn get_objective(ref self: ContractState, token_id: u64, objective_index: u32) -> TokenObjective {
//         self.objectives.get_objective(token_id, objective_index)
//     }
//     
//     fn set_objective(ref self: ContractState, token_id: u64, objective_index: u32, objective: TokenObjective) {
//         self.objectives.set_objective(token_id, objective_index, objective)
//     }
// } 