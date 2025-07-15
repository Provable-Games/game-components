#!/bin/bash

# Optimized Token Contract Deployment Script
# Deploys the OptimizedTokenContract from the game-components-token package

set -euo pipefail

# ============================
# STARKLI VERSION CHECK
# ============================

STARKLI_VERSION=$(starkli --version | cut -d' ' -f1)
echo "Detected starkli version: $STARKLI_VERSION"

# # Check if version is 0.3.x for RPC compatibility
# if [[ ! "$STARKLI_VERSION" =~ ^0\.3\. ]]; then
#     echo "WARNING: starkli version $STARKLI_VERSION may have RPC compatibility issues with Sepolia."
#     echo "Consider running: starkliup -v 0.3.8"
#     echo ""
# fi

# Load environment variables from .env file if it exists
# Check in current directory first, then parent directories
if [ -f .env ]; then
    set -a
    source .env
    set +a
    echo "Loaded environment variables from .env file"
elif [ -f ../.env ]; then
    set -a
    source ../.env
    set +a
    echo "Loaded environment variables from ../.env file"
elif [ -f ../../.env ]; then
    set -a
    source ../../.env
    set +a
    echo "Loaded environment variables from ../../.env file"
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check deployment environment
DEPLOY_TO_SLOT="${DEPLOY_TO_SLOT:-false}"

# Check if required environment variables are set
print_info "Checking environment variables..."

# Determine required vars based on deployment type
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    print_info "Deploying to Slot - reduced requirements"
    required_vars=("STARKNET_ACCOUNT" "STARKNET_RPC")
else
    required_vars=("STARKNET_NETWORK" "STARKNET_ACCOUNT" "STARKNET_RPC" "STARKNET_PK")
fi

missing_vars=()

# Debug output for environment variables
print_info "Environment variables loaded:"
echo "  DEPLOY_TO_SLOT: $DEPLOY_TO_SLOT"
echo "  STARKNET_NETWORK: ${STARKNET_NETWORK:-<not set>}"
echo "  STARKNET_ACCOUNT: ${STARKNET_ACCOUNT:-<not set>}"
echo "  STARKNET_RPC: ${STARKNET_RPC:-<not set>}"
echo "  STARKNET_PK: ${STARKNET_PK:+<set>}"

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "The following required environment variables are not set:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo "Please set these variables before running the script."
    exit 1
fi

# Check that private key is set (only for non-Slot deployments)
if [ "$DEPLOY_TO_SLOT" != "true" ]; then
    if [ -z "${STARKNET_PK:-}" ]; then
        print_error "STARKNET_PK environment variable is not set"
        exit 1
    fi
    print_warning "Using private key (insecure for production)"
fi

# ============================
# CONFIGURATION PARAMETERS
# ============================

# Token Parameters
TOKEN_NAME="${TOKEN_NAME:-TestGameToken}"
TOKEN_SYMBOL="${TOKEN_SYMBOL:-TGT}"
TOKEN_BASE_URI="${TOKEN_BASE_URI:-https://api.game.com/token/}"

# Optional addresses (can be set via environment variables)
GAME_ADDRESS="${GAME_ADDRESS:-}"
GAME_REGISTRY_ADDRESS="${GAME_REGISTRY_ADDRESS:-}"
RELAYER_ADDRESS="${RELAYER_ADDRESS:-}"

# ============================
# DISPLAY CONFIGURATION
# ============================

print_info "Optimized Token Contract Deployment Configuration:"
echo "  Deployment Type: $(if [ "$DEPLOY_TO_SLOT" = "true" ]; then echo "Slot"; else echo "Standard"; fi)"
echo "  Network: ${STARKNET_NETWORK:-<not required for Slot>}"
echo "  Account: $STARKNET_ACCOUNT"
echo "  Token Name: $TOKEN_NAME"
echo "  Token Symbol: $TOKEN_SYMBOL"
echo "  Base URI: $TOKEN_BASE_URI"
echo "  Game Address: ${GAME_ADDRESS:-<not set>}"
echo "  Game Registry Address: ${GAME_REGISTRY_ADDRESS:-<not set>}"
echo "  Relayer Address: ${RELAYER_ADDRESS:-<not set>}"

# Confirm deployment
if [ "${SKIP_CONFIRMATION:-false}" != "true" ]; then
    read -p "Continue with deployment? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
fi

# ============================
# BUILD CONTRACT
# ============================

print_info "Building Optimized Token contract..."
scarb build

if [ ! -f "target/dev/game_components_token_OptimizedTokenContract.contract_class.json" ]; then
    print_error "Contract build failed or contract file not found"
    print_error "Expected: target/dev/game_components_token_OptimizedTokenContract.contract_class.json"
    echo "Available contract files:"
    ls -la target/dev/*.contract_class.json 2>/dev/null || echo "No contract files found"
    exit 1
fi

# ============================
# DECLARE CONTRACT
# ============================

print_info "Declaring Optimized Token contract..."

# Build declare command based on deployment type
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    DECLARE_OUTPUT=$(starkli declare --account $STARKNET_ACCOUNT --rpc $STARKNET_RPC --watch target/dev/game_components_token_OptimizedTokenContract.contract_class.json 2>&1)
else
    DECLARE_OUTPUT=$(starkli declare --account $STARKNET_ACCOUNT --rpc $STARKNET_RPC --watch target/dev/game_components_token_OptimizedTokenContract.contract_class.json --private-key $STARKNET_PK 2>&1)
fi

# Extract class hash from output
CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oE '0x[0-9a-fA-F]+' | tail -1)

if [ -z "$CLASS_HASH" ]; then
    # Contract might already be declared, try to extract from error message
    if echo "$DECLARE_OUTPUT" | grep -q "already declared"; then
        CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oE 'class_hash: 0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+')
        print_warning "Contract already declared with class hash: $CLASS_HASH"
    else
        print_error "Failed to declare contract"
        echo "$DECLARE_OUTPUT"
        exit 1
    fi
else
    print_info "Contract declared with class hash: $CLASS_HASH"
fi

# ============================
# PREPARE CONSTRUCTOR ARGUMENTS  
# ============================

print_info "Preparing constructor arguments..."

# Constructor parameters for OptimizedTokenContract:
# - name: ByteArray
# - symbol: ByteArray  
# - base_uri: ByteArray
# - game_address: Option<ContractAddress>
# - game_registry_address: Option<ContractAddress>

# Using starkli's built-in bytearray conversion
TOKEN_NAME_ARG="bytearray:str:$TOKEN_NAME"
TOKEN_SYMBOL_ARG="bytearray:str:$TOKEN_SYMBOL"
TOKEN_BASE_URI_ARG="bytearray:str:$TOKEN_BASE_URI"

print_info "Token name: '$TOKEN_NAME' -> $TOKEN_NAME_ARG"
print_info "Token symbol: '$TOKEN_SYMBOL' -> $TOKEN_SYMBOL_ARG" 
print_info "Base URI: '$TOKEN_BASE_URI' -> $TOKEN_BASE_URI_ARG"

# ============================
# DEPLOY CONTRACT
# ============================

print_info "Deploying Optimized Token contract..."

# Execute deployment
print_info "Executing deployment with starkli..."
print_info "Command: starkli deploy"
print_info "Class hash: $CLASS_HASH"

# # Check if we should use ETH or STRK for fees
# FEE_TOKEN_FLAG=""
# if [ "${USE_ETH_FEES:-false}" == "true" ]; then
#     FEE_TOKEN_FLAG="--eth"
#     print_warning "Using ETH for transaction fees (deprecated)"
# else
#     FEE_TOKEN_FLAG="--strk"
#     print_info "Using STRK for transaction fees"
# fi

# Deploy with starkli bytearray conversion
# Option format: 0 [value] for Some, 1 for None
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    CONTRACT_ADDRESS=$(starkli deploy \
        --account $STARKNET_ACCOUNT \
        --rpc $STARKNET_RPC \
        --watch \
        $CLASS_HASH \
        "$TOKEN_NAME_ARG" \
        "$TOKEN_SYMBOL_ARG" \
        "$TOKEN_BASE_URI_ARG" \
        $(if [ -n "$GAME_ADDRESS" ]; then echo "0 $GAME_ADDRESS"; else echo "1"; fi) \
        $(if [ -n "$GAME_REGISTRY_ADDRESS" ]; then echo "0 $GAME_REGISTRY_ADDRESS"; else echo "1"; fi) \
        $(if [ -n "$RELAYER_ADDRESS" ]; then echo "0 $RELAYER_ADDRESS"; else echo "1"; fi) \
        2>&1 | tee >(cat >&2) | grep -oE '0x[0-9a-fA-F]{64}' | tail -1)
else
    CONTRACT_ADDRESS=$(starkli deploy \
        --account $STARKNET_ACCOUNT \
        --rpc $STARKNET_RPC \
        --private-key $STARKNET_PK \
        --watch \
        $CLASS_HASH \
        "$TOKEN_NAME_ARG" \
        "$TOKEN_SYMBOL_ARG" \
        "$TOKEN_BASE_URI_ARG" \
        $(if [ -n "$GAME_ADDRESS" ]; then echo "0 $GAME_ADDRESS"; else echo "1"; fi) \
        $(if [ -n "$GAME_REGISTRY_ADDRESS" ]; then echo "0 $GAME_REGISTRY_ADDRESS"; else echo "1"; fi) \
        $(if [ -n "$RELAYER_ADDRESS" ]; then echo "0 $RELAYER_ADDRESS"; else echo "1"; fi) \
        2>&1 | tee >(cat >&2) | grep -oE '0x[0-9a-fA-F]{64}' | tail -1)
fi

if [ -z "$CONTRACT_ADDRESS" ]; then
    print_error "Failed to deploy contract"
    exit 1
fi

print_info "Optimized Token contract deployed at address: $CONTRACT_ADDRESS"

# ============================
# SAVE DEPLOYMENT INFO
# ============================

DEPLOYMENT_FILE="deployments/optimized_token_$(date +%Y%m%d_%H%M%S).json"
mkdir -p deployments

cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "${STARKNET_NETWORK:-slot}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contract_address": "$CONTRACT_ADDRESS",
  "class_hash": "$CLASS_HASH",
  "parameters": {
    "name": "$TOKEN_NAME",
    "symbol": "$TOKEN_SYMBOL",
    "base_uri": "$TOKEN_BASE_URI",
    "game_address": "${GAME_ADDRESS:-null}",
    "game_registry_address": "${GAME_REGISTRY_ADDRESS:-null}",
    "relayer_address": "${RELAYER_ADDRESS:-null}"
  }
}
EOF

print_info "Deployment info saved to: $DEPLOYMENT_FILE"

# ============================
# DEPLOYMENT SUMMARY
# ============================

echo
print_info "=== OPTIMIZED TOKEN CONTRACT DEPLOYMENT SUCCESSFUL ==="
echo "Contract Address: $CONTRACT_ADDRESS"
echo "Class Hash: $CLASS_HASH"
echo "Token Name: $TOKEN_NAME"
echo "Token Symbol: $TOKEN_SYMBOL"
echo "Base URI: $TOKEN_BASE_URI"
echo

echo "Next steps:"
echo "1. Test the token by minting your first NFT"
echo "2. Configure game address if not set during deployment"
echo "3. Set up objectives and other extensions as needed"
echo

echo "To interact with the contract:"
echo "  export TOKEN_CONTRACT=$CONTRACT_ADDRESS"
echo

echo "Example: Mint a token (replace with appropriate parameters):"
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    echo "  starkli invoke --account \$STARKNET_ACCOUNT --watch \$TOKEN_CONTRACT mint \\"
    echo "    1 0 0 0 0 0 0 0 0 \$STARKNET_ACCOUNT 0"
else
    echo "  starkli invoke --account \$STARKNET_ACCOUNT --watch \$TOKEN_CONTRACT mint \\"
    echo "    1 0 0 0 0 0 0 0 0 \$STARKNET_ACCOUNT 0 --private-key \$STARKNET_PK"
fi

# If there is an event relayer we need to initialize it with the token address
if [ -n "$RELAYER_ADDRESS" ]; then
    echo
    print_info "Initializing event relayer with token address: $CONTRACT_ADDRESS"
    
    if [ "$DEPLOY_TO_SLOT" = "true" ]; then
        starkli invoke \
            --account $STARKNET_ACCOUNT \
            --rpc $STARKNET_RPC \
            --watch \
            $RELAYER_ADDRESS \
            initialize \
            $CONTRACT_ADDRESS
    else
        starkli invoke \
            --account $STARKNET_ACCOUNT \
            --rpc $STARKNET_RPC \
            --private-key $STARKNET_PK \
            --watch \
            $RELAYER_ADDRESS \
            initialize \
            $CONTRACT_ADDRESS
    fi
    
    if [ $? -eq 0 ]; then
        print_info "Event relayer initialized successfully"
    else
        print_error "Failed to initialize event relayer"
        exit 1
    fi
fi