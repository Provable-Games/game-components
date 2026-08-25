/// Metagame Component
///
/// Self-binding, like `MinigameTokenComponent`: the embedding contract IS the
/// metagame. It holds no addresses — no default token (each game brings its
/// own, resolved per mint) and no context address (a metagame that provides
/// context embeds `ContextComponent` itself, which registers
/// `IMETAGAME_CONTEXT_ID` on this same contract).
///
/// With no addresses left to expose, there is no `IMetagame` ABI: the
/// component is a set of internal helpers over `metagame::metagame` (`libs`),
/// each branching on SRC5 to serve both token generations.
#[starknet::component]
pub mod MetagameComponent {
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
    use game_components_interfaces::structs::token::MintBatchRecipient;
    use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::contract_address::ContractAddress;
    use crate::metagame::metagame as libs;
    use crate::metagame::structs::MintMetagameParams;

    /// Self-bound: no addresses to hold.
    #[storage]
    pub struct Storage {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn assert_game_registered(
            ref self: ComponentState<TContractState>, game_address: ContractAddress,
        ) {
            libs::assert_game_registered(game_address);
        }

        fn mint(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            to: ContractAddress,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u128,
        ) -> felt252 {
            libs::mint(
                game_address,
                player_name,
                settings_id,
                start,
                end,
                objective_id,
                context,
                client_url,
                renderer_address,
                skills_address,
                to,
                soulbound,
                paymaster,
                salt,
                metadata,
            )
        }

        fn mint_batch(
            ref self: ComponentState<TContractState>, mints: Array<MintMetagameParams>,
        ) -> Array<felt252> {
            libs::mint_batch(mints)
        }

        /// Many tokens for ONE game in a single dispatch, via the token's own
        /// `mint_batch_recipients`. Prefer this over `mint_batch` whenever the
        /// batch shares a game: `mint_batch` costs one cross-contract call per
        /// token and re-serialises `context` each time.
        fn mint_batch_recipients(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            player_name: Option<felt252>,
            settings_id: Option<u32>,
            start: Option<u64>,
            end: Option<u64>,
            objective_id: Option<u32>,
            context: Option<GameContextDetails>,
            client_url: Option<ByteArray>,
            renderer_address: Option<ContractAddress>,
            skills_address: Option<ContractAddress>,
            recipients: Array<MintBatchRecipient>,
            soulbound: bool,
            paymaster: bool,
            salt: u16,
            metadata: u128,
        ) -> Array<felt252> {
            libs::mint_batch_recipients(
                game_address,
                player_name,
                settings_id,
                start,
                end,
                objective_id,
                context,
                client_url,
                renderer_address,
                skills_address,
                recipients,
                soulbound,
                paymaster,
                salt,
                metadata,
            )
        }

        /// Resolves the game's fee terms and pays them via ERC20. Returns the
        /// amount paid, 0 if the game charges nothing — a game that declares no
        /// fee at all answers zero too, so this short-circuits before it ever
        /// needs a recipient. Terms and recipient come from the token's game-fee
        /// surface for standard tokens, from the registry for legacy ones.
        fn pay_game_fee(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            payment_token: ContractAddress,
            revenue: u128,
        ) -> u128 {
            // One resolution answers both questions. This was two calls while
            // the retired generation answered terms and payee in different
            // places; the game-fee surface returns them together.
            let terms = libs::get_game_fee_terms(game_address);
            let fee_amount = libs::calculate_game_fee(revenue, terms.fee_numerator);
            if fee_amount == 0 {
                return 0;
            }
            let recipient = terms.recipient;

            // Transfer fee. ERC20s that signal failure by returning false
            // instead of reverting must not be reported as a paid fee.
            let erc20 = IERC20Dispatcher { contract_address: payment_token };
            assert!(
                erc20.transfer(recipient, fee_amount.into()), "Metagame: game fee transfer failed",
            );

            fee_amount
        }
    }
}
