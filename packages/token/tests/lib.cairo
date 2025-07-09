pub mod mocks {
    pub mod mock_metagame;
    pub mod mock_minigame;
    pub mod mock_settings;
    pub mod mock_objectives;
    pub mod mock_context;
    pub mod mock_renderer;
}

pub mod unit {
    #[cfg(test)]
    pub mod test_token_component;
    #[cfg(test)]
    pub mod test_minter_component;
}

pub mod integration {
    #[cfg(test)]
    pub mod test_simple_token_example;
    #[cfg(test)]
    pub mod test_advanced_token_example;
    #[cfg(test)]
    pub mod test_full_featured_token_example;
}
