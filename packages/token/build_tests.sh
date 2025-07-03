#!/bin/bash
# Build test package from workspace root
pushd /workspace/game-components > /dev/null
scarb build -p game_components_test_starknet
popd > /dev/null