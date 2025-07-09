pub mod mocks {
    pub mod mock_minigame;
    pub mod mock_settings;
    pub mod mock_objectives;
    pub mod mock_context;
    pub mod mock_token;
}

pub mod unit {
    #[cfg(test)]
    pub mod test_basic;
    // #[cfg(test)]
    // pub mod test_token_core;
    // #[cfg(test)]
    // pub mod test_hooks_empty;
    // #[cfg(test)]
    // pub mod test_hooks_validation;
    // #[cfg(test)]
    // pub mod test_extensions;
}

// pub mod fuzz {
//     #[cfg(test)]
//     pub mod test_mint_fuzz;
// }

// pub mod property {
//     #[cfg(test)]
//     pub mod test_invariants;
// }

// pub mod integration {
//     #[cfg(test)]
//     pub mod test_gameplay_flow;
// }