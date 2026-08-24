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
            metadata: u16,
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

        /// Reads fee from registry, calculates amount, transfers via ERC20
        /// to the game's creator token owner. Returns fee amount (0 if no fee).
        fn pay_game_fee(
            ref self: ComponentState<TContractState>,
            game_address: ContractAddress,
            payment_token: ContractAddress,
            revenue: u128,
        ) -> u128 {
            let fee_info = libs::get_game_fee_info(game_address);
            let fee_amount = libs::calculate_game_fee(revenue, fee_info.fee_numerator);
            if fee_amount == 0 {
                return 0;
            }

            // Resolve the fee recipient: standard tokens name the payee
            // directly, legacy registry tokens go through the registry NFT's
            // current owner.
            let recipient = libs::get_game_creator_address(game_address);

            // Transfer fee
            let erc20 = IERC20Dispatcher { contract_address: payment_token };
            erc20.transfer(recipient, fee_amount.into());

            fee_amount
        }
    }
}
