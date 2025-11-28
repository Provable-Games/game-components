pub mod mocks {
    pub mod mock_minigame_token;
    pub mod mock_context;
    pub mod mock_context_contract;
    pub mod mock_src5;
    pub mod mock_minigame;
    pub mod mock_settings;
    pub mod mock_objectives;
    pub mod mock_metagame_contract;
    pub mod mock_token_contract;
    pub mod mock_metagame_with_context;
}
pub mod unit {
    #[cfg(test)]
    pub mod test_metagame_component;
    #[cfg(test)]
    pub mod test_context_component;
}

pub mod integration {
    #[cfg(test)]
    pub mod test_tournament_flow;
}

pub mod fuzz {
    #[cfg(test)]
    pub mod test_fuzz_mint_parameters;
}
