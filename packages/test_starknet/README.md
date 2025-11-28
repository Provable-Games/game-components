# Game Components Test - Starknet

This package contains Starknet-native tests and mocks for the game components library.

## Purpose

This package is designed to test components using pure Starknet storage without Dojo dependencies. It includes:

- Starknet-native mock contracts using Map and Vec storage
- Unit tests using Starknet Foundry (snforge)
- Performance and isolated testing without Dojo overhead

## Dependencies

- Starknet
- Starknet Foundry (snforge)
- OpenZeppelin contracts

## Structure

- `src/minigame/` - Minigame component tests using Starknet storage
- `src/metagame/` - Metagame component tests using Starknet storage

## Requirements

Ensure you have the correct version of Starknet Foundry specified in `.tool-versions`:

```
starknet-foundry 0.31.0
```

## Usage

Use this package when you need fast, isolated testing of components without Dojo dependencies.

```bash
cd packages/test_starknet
scarb build
```

To run Starknet Foundry tests:
```bash
snforge test
``` 