// This file demonstrates why hooks are the optimal architecture
// by showing what the code would look like WITHOUT hooks

// ===== WITHOUT HOOKS - Tightly Coupled =====
mod TokenWithoutHooks {
    #[storage]
    struct Storage {
        token_data: Map<u64, TokenData>,
        game_address: ContractAddress,
        // Must include ALL possible storage even if not used
        minter_registry: Map<ContractAddress, u64>,
        objectives_data: Map<u64, Span<u32>>,
        settings_cache: Map<u64, u32>,
    }
    
    fn mint(
        ref self: ContractState,
        to: ContractAddress,
        token_id: u64,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        objective_ids: Option<Span<u32>>,
    ) {
        // Problem 1: Core logic mixed with optional validation
        match game_address {
            Option::Some(addr) => {
                // Validation logic embedded in mint function
                validate_game_address(addr);
                
                // Problem 2: Runtime checks for features
                if self.supports_settings && settings_id.is_some() {
                    validate_settings(addr, settings_id.unwrap());
                }
                
                if self.supports_objectives && objective_ids.is_some() {
                    validate_objectives(addr, objective_ids.unwrap());
                }
            },
            Option::None => { /* ... */ }
        }
        
        // Core mint logic
        self._mint(to, token_id);
        
        // Problem 3: Post-mint logic also embedded
        if self.supports_minter {
            self.minter_registry.write(get_caller_address(), self.minter_count);
        }
        
        // Problem 4: Can't easily add new features without modifying this function
    }
}

// ===== WITH HOOKS - Clean Separation =====
mod TokenWithHooks {
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    
    // Clean: Core component has NO knowledge of extensions
    // The mint function in TokenComponent just calls hooks:
    // let validation = hooks.before_mint(...);
    // self._mint(to, token_id);  
    // hooks.after_mint(...);
    
    // Option 1: Minimal - compiles to almost nothing
    impl MinimalHooks of TokenHooksTrait<ContractState> {
        fn before_mint(...) -> (u64, u32, u32) {
            (0, 0, 0) // Optimized away by compiler
        }
        fn after_mint(...) {} // No code generated
    }
    
    // Option 2: Full features - only pay for what you use
    impl FullHooks of TokenHooksTrait<ContractState> {
        fn before_mint(...) -> (u64, u32, u32) {
            // All validation logic here
            validate_game_address(game_addr);
            let settings = validate_settings(...);
            let objectives = validate_objectives(...);
            (0, settings, objectives)
        }
        fn after_mint(...) {
            // All post-processing here
            register_minter(caller_address);
        }
    }
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
        // Only include storage for features you actually use!
        // No minter storage if not using minter
        // No objectives storage if not using objectives
    }
}

// ===== COMPARISON: Adding a New Feature =====

// WITHOUT HOOKS: Must modify core mint function
// - Edit mint() to add new validation
// - Add new storage fields
// - Risk breaking existing functionality
// - All tokens must pay storage cost

// WITH HOOKS: Just implement different hooks
impl TokenHooksWithNewFeature of TokenHooksTrait<ContractState> {
    fn before_mint(...) -> (u64, u32, u32) {
        // Add your new validation here
        validate_new_feature();
        // Existing validation...
    }
    fn after_mint(...) {
        // Add your new post-processing here
        process_new_feature();
    }
}

// ===== GAS COST COMPARISON =====

// WITHOUT HOOKS - Minimal Token:
// - Storage: Pays for ALL fields (minter, objectives, etc.)
// - Runtime: if checks for features add ~200 gas each
// - Total overhead: ~1000 gas even if not using features

// WITH HOOKS - Minimal Token:  
// - Storage: Only core fields
// - Runtime: Empty hooks compile away
// - Total overhead: 0 gas

// ===== WHY HOOKS WIN =====
// 1. Zero overhead when not used (empty hooks optimize away)
// 2. Clean separation (core doesn't know about extensions)
// 3. Compile-time composition (pick your hooks impl)
// 4. Storage efficiency (only include what you need)
// 5. Easy to extend (just write new hooks)
// 6. Type safe (compiler ensures components match)