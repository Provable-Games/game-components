pub use game_components_test_common::mocks::{
    mock_erc20, mock_game_details, mock_leaderboard_contract,
};
pub mod mock_registry;

pub use mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait, MockERC20};
pub use mock_game_details::{IMockGameDetailsAdminDispatcher, IMockGameDetailsAdminDispatcherTrait};
pub use mock_registry::{IMockTokenRegistryDispatcher, IMockTokenRegistryDispatcherTrait};
