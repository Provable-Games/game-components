Plan: Merge Packages into Group Packages │
│ │
│ Context │
│ │
│ The user wants the group directories to BE the Scarb packages, with individual packages becoming modules within them. This reduces 17 workspace members to 8, simplifies │
│ dependency management for consumers like budokan, and makes the package structure match the logical groupings. │
│ │
│ Current state: Packages already moved into group subdirectories (Phase 1 complete), but still as individual Scarb packages. │
│ │
│ Target Package Structure │
│ │
│ ┌──────────────────────────────────────────┬────────────────────────────────────────────────────────────────┐ │
│ │ Group Package Name │ Modules (old packages) │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game*components_embeddable_game_standard │ token, minigame, metagame, registry │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game_components_metagame (group) │ leaderboard, registration, entry_requirement, entry_fee, prize │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game_components_economy │ tokenomics │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game_components_utilities │ math, distribution, utils │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game_components_interfaces │ unchanged (flat) │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game_components_presets │ unchanged (flat) │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game_components_testing │ unchanged (flat) │ │
│ ├──────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤ │
│ │ game_components_test_common │ unchanged (flat) │ │
│ └──────────────────────────────────────────┴────────────────────────────────────────────────────────────────┘ │
│ │
│ Target filesystem: │
│ │
│ packages/<group>/ │
│ Scarb.toml # Single combined package │
│ src/ │
│ lib.cairo # pub mod token; pub mod minigame; ... │
│ token.cairo # Content of old token/src/lib.cairo │
│ token/ # Content of old token/src/* (except lib.cairo) │
│ minigame.cairo │
│ minigame/ │
│ ... │
│ │
│ │
│ Import Path Mapping │
│ │
│ All use statements in .cairo files change: │
│ │
│ ┌──────────────────────────────────────┬───────────────────────────────────────────────────────┐ │
│ │ Old │ New │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_token::X │ game_components_embeddable_game_standard::token::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_minigame::X │ game_components_embeddable_game_standard::minigame::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_metagame::X │ game_components_embeddable_game_standard::metagame::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_registry::X │ game_components_embeddable_game_standard::registry::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_leaderboard::X │ game_components_metagame::leaderboard::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_registration::X │ game_components_metagame::registration::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_entry_requirement::X │ game_components_metagame::entry_requirement::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_entry_fee::X │ game_components_metagame::entry_fee::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_prize::X │ game_components_metagame::prize::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_tokenomics::X │ game_components_economy::tokenomics::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_math::X │ game_components_utilities::math::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_distribution::X │ game_components_utilities::distribution::X │ │
│ ├──────────────────────────────────────┼───────────────────────────────────────────────────────┤ │
│ │ game_components_utils::X │ game_components_utilities::utils::X │ │
│ └──────────────────────────────────────┴───────────────────────────────────────────────────────┘ │
│ │
│ Critical ordering: game_components_metagame:: (old EGS metagame) must be replaced BEFORE game_components_leaderboard:: → game_components_metagame::leaderboard:: to avoid │
│ double-replacement. │
│ │
│ Execution Steps │
│ │
│ Step 1: Create group package file structures │
│ │
│ For each group (embeddable_game_standard, metagame, economy, utilities): │
│ 1. Create packages/<group>/src/lib.cairo declaring sub-modules │
│ 2. Move each <sub>/src/lib.cairo → <group>/src/<sub>.cairo │
│ 3. Move each <sub>/src/* (except lib.cairo) → <group>/src/<sub>/ │
│ 4. Create combined <group>/Scarb.toml (union of all sub-package deps) │
│ 5. Delete old <sub>/Scarb.toml and empty <sub>/src/ dirs │
│ │
│ Step 2: Global import replacement (two-pass sed) │
│ │
│ Pass 1 — Replace old game_components_metagame:: first (before it gets claimed by the group): │
│ │
│ game_components_metagame:: → game_components_embeddable_game_standard::metagame:: │
│ │
│ │
│ Pass 2 — Replace all other old package names: │
│ │
│ game_components_token:: → game_components_embeddable_game_standard::token:: │
│ game_components_minigame:: → game_components_embeddable_game_standard::minigame:: │
│ game_components_registry:: → game_components_embeddable_game_standard::registry:: │
│ game_components_leaderboard:: → game_components_metagame::leaderboard:: │
│ game_components_registration:: → game_components_metagame::registration:: │
│ game_components_entry_requirement:: → game_components_metagame::entry_requirement:: │
│ game_components_entry_fee:: → game_components_metagame::entry_fee:: │
│ game_components_prize:: → game_components_metagame::prize:: │
│ game_components_tokenomics:: → game_components_economy::tokenomics:: │
│ game_components_math:: → game_components_utilities::math:: │
│ game_components_distribution:: → game_components_utilities::distribution:: │
│ game_components_utils:: → game_components_utilities::utils:: │
│ │
│ │
│ Apply to ALL .cairo files in /workspace/game-components/ and /workspace/budokan/. │
│ │
│ Note: Within-crate references (e.g., token referencing minigame within EGS) will use the full crate name game_components_embeddable_game_standard::minigame::... which is valid │
│ in Cairo (you can use your own crate name from within the crate). │
│ │
│ Step 3: Update Scarb.toml files │
│ │
│ Root Scarb.toml: Update workspace members to 8 entries, update [dependencies] paths. │
│ │
│ Flat packages (presets, test_common): Replace individual dep entries with group package deps. │
│ │
│ Budokan Scarb.toml: Replace 15 individual deps with ~7 group deps (local paths for dev). │
│ │
│ Step 4: Update CI and documentation │
│ │
│ - .github/workflows/test.yml: Matrix shrinks from 14 to ~8 packages; adjust runner sizes │
│ - codecov.yml: Update after_n_builds count │
│ - README.md: Update package links │
│ - AGENTS.md: Update package table │
│ │
│ Step 5: Verify │
│ │
│ scarb build │
│ scarb fmt -w │
│ snforge test -p game_components_embeddable_game_standard │
│ snforge test -p game_components_metagame │
│ snforge test -p game_components_economy │
│ snforge test -p game_components_utilities │
│ snforge test -p game_components_presets │
│ # budokan │
│ cd /workspace/budokan && scarb build && snforge test │
│ │
│ │
│ Combined Scarb.toml Dependencies │
│ │
│ game_components_embeddable_game_standard: │
│ - starknet, openzeppelin*{token,introspection,interfaces,access} │
│ - game*components_interfaces, game_components_utilities, game_components_metagame │
│ - Dev: snforge_std, game_components_testing, game_components_test_common │
│ - [[target.starknet-contract]] sierra=true, casm=true │
│ │
│ game_components_metagame (group): │
│ - starknet, openzeppelin*{interfaces,introspection} │
│ - game*components_interfaces, game_components_utilities │
│ - Dev: snforge_std, game_components_testing, game_components_test_common, openzeppelin_interfaces │
│ - [[target.starknet-contract]] │
│ │
│ game_components_economy: │
│ - starknet, openzeppelin*{access,token,interfaces}, ekubo │
│ - game_components_interfaces │
│ - Dev: snforge_std, game_components_testing │
│ - [[target.starknet-contract]] sierra=true │
│ - [tool.snforge] fuzzer_runs=24, fork config for MAINNET │
│ │
│ game_components_utilities: │
│ - starknet, game_components_interfaces, game_components_embeddable_game_standard │
│ - alexandria_encoding, graffiti (git deps for utils module) │
│ - Dev: snforge_std │
│ │
│ Risks │
│ │
│ ┌─────────────────────────────────────────┬──────────────────────────────────────────────────┐ │
│ │ Risk │ Mitigation │ │
│ ├─────────────────────────────────────────┼──────────────────────────────────────────────────┤ │
│ │ Circular dep EGS ↔ utilities │ Already works in current codebase; same topology │ │
│ ├─────────────────────────────────────────┼──────────────────────────────────────────────────┤ │
│ │ game_components_metagame name collision │ Two-pass sed: rename old refs first │ │
│ ├─────────────────────────────────────────┼──────────────────────────────────────────────────┤ │
│ │ ~100+ files with import changes │ Mechanical sed; scarb build catches all errors │ │
│ ├─────────────────────────────────────────┼──────────────────────────────────────────────────┤ │
│ │ Test discovery in nested modules │ snforge finds #[test] at any depth │
