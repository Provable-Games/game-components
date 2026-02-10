## Package: entry_requirement

Entry requirement component for gating access to contexts (tournaments, quests, etc.).

Supports three requirement types:
- **Token**: Requires ownership of a specific NFT
- **Allowlist**: Requires address to be in an allowlist
- **Extension**: Delegates validation to an external IEntryValidator contract

Also includes the EntryValidatorComponent base for building custom validator contracts.

## Dependencies
- `game_components_interfaces` - EntryRequirement types and IEntryValidator interface
- `openzeppelin_interfaces` - ERC20/ERC721 interfaces
- `openzeppelin_introspection` - SRC5 interface registration
