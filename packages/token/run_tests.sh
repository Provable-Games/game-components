#!/bin/bash

# Script to run token package tests

echo "Running token package tests..."

# Build the package first
echo "Building token package..."
scarb build -p game_components_token

# Run tests with snforge
echo "Running tests..."
snforge test -p game_components_token --detailed-resources

echo "Test run complete!"