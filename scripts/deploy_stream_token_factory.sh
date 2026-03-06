#!/bin/bash

# =============================================================================
# StreamTokenFactory Deployment Script
# =============================================================================
#
# Deploys the StreamTokenFactory contract to Starknet using sncast CLI.
# This script is idempotent - it handles already-declared contracts gracefully.
#
# Prerequisites:
#   - sncast account configured (sncast account create/import)
#   - Sufficient funds in the account for gas
#   - scarb and snforge installed
#
# Required Environment Variables:
#   SNCAST_ACCOUNT    - Name of the sncast account to use
#   FACTORY_OWNER     - Address that will own the factory contract
#
# Optional Environment Variables:
#   STARKNET_RPC           - RPC endpoint (default: Cartridge mainnet)
#   STARKNET_NETWORK       - Network name for verification (default: mainnet)
#   SKIP_CONFIRMATION      - Set to "true" to skip confirmation prompt
#   SKIP_VERIFICATION      - Set to "true" to skip Voyager verification
#   VERBOSE                - Set to "true" for detailed output
#
# Ekubo Address Overrides (defaults to mainnet addresses):
#   EKUBO_POSITIONS_ADDRESS
#   EKUBO_CORE_ADDRESS
#   EKUBO_EXTENSION_ADDRESS
#   EKUBO_REGISTRY_ADDRESS
#
# Usage:
#   export SNCAST_ACCOUNT=myaccount
#   export FACTORY_OWNER=0x...
#   ./scripts/deploy_stream_token_factory.sh
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTS
# =============================================================================

# Ekubo mainnet addresses
readonly DEFAULT_EKUBO_POSITIONS="0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067"
readonly DEFAULT_EKUBO_CORE="0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b"
readonly DEFAULT_EKUBO_EXTENSION="0x043e4f09c32d13d43a880e85f69f7de93ceda62d6cf2581a582c6db635548fdc"
readonly DEFAULT_EKUBO_REGISTRY="0x064bdb4094881140bc39340146c5fcc5a187a98aec5a53f448ac702e5de5067e"

# Default RPC
readonly DEFAULT_RPC="https://api.cartridge.gg/x/starknet/mainnet/rpc/v0_10"

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

# Load .env if present
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$REPO_ROOT/.env"
    set +a
fi

# =============================================================================
# OUTPUT HELPERS
# =============================================================================

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_step()    { echo -e "${BLUE}[STEP]${NC} $1"; }
print_verbose() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "$1" || true; }

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Validate that a string looks like a Starknet address (0x followed by hex)
validate_address() {
    local address="$1"
    local name="$2"
    if [[ ! "$address" =~ ^0x[0-9a-fA-F]+$ ]]; then
        print_error "Invalid $name: '$address' (must be hex starting with 0x)"
        return 1
    fi
}

# Extract class hash from sncast declare output
# Handles both successful declarations and "already declared" errors
extract_class_hash() {
    local output="$1"
    local class_hash=""

    # Pattern 1: Successful declaration - "Class Hash: 0x..."
    class_hash=$(echo "$output" | grep -iE 'class.hash:?\s*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | head -1)

    # Pattern 2: Already declared - "class hash 0x... is already declared"
    if [ -z "$class_hash" ] && echo "$output" | grep -qi "already declared"; then
        class_hash=$(echo "$output" | grep -oE '0x[0-9a-fA-F]{50,}' | head -1)
    fi

    echo "$class_hash"
}

# Extract contract address from sncast deploy output
extract_contract_address() {
    local output="$1"
    echo "$output" | grep -iE 'contract.address:?\s*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | head -1
}

# Extract transaction hash from sncast output
extract_transaction_hash() {
    local output="$1"
    echo "$output" | grep -iE 'transaction.hash:?\s*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | head -1
}

# Declare a contract and return its class hash
# Arguments: package_name contract_name
# Returns: class_hash via stdout, sets DECLARE_TX_HASH global
declare_contract() {
    local package="$1"
    local contract="$2"

    local output
    output=$(sncast --account "$SNCAST_ACCOUNT" \
        declare \
        --url "$STARKNET_RPC" \
        --package "$package" \
        --contract-name "$contract" 2>&1) || true

    print_verbose "$output"

    local class_hash
    class_hash=$(extract_class_hash "$output")

    if [ -z "$class_hash" ]; then
        print_error "Failed to declare $contract or extract class hash"
        print_error "Output: $output"
        return 1
    fi

    # Set global for transaction hash (may be empty if already declared)
    DECLARE_TX_HASH=$(extract_transaction_hash "$output")

    if echo "$output" | grep -qi "already declared"; then
        print_warning "$contract already declared with class hash: $class_hash"
    else
        print_info "$contract declared with class hash: $class_hash"
        [ -n "$DECLARE_TX_HASH" ] && print_info "Transaction: $DECLARE_TX_HASH"
    fi

    echo "$class_hash"
}

# Verify a contract on Voyager
# Arguments: class_hash contract_name package_name
verify_contract() {
    local class_hash="$1"
    local contract="$2"
    local package="$3"

    if [[ "${SKIP_VERIFICATION:-false}" == "true" ]]; then
        print_warning "Skipping verification for $contract (SKIP_VERIFICATION=true)"
        return 0
    fi

    local output
    output=$(sncast verify \
        --class-hash "$class_hash" \
        --contract-name "$contract" \
        --verifier voyager \
        --network "$STARKNET_NETWORK" \
        --package "$package" \
        --confirm-verification 2>&1) || true

    print_verbose "$output"

    if echo "$output" | grep -qi "success\|submitted"; then
        print_info "$contract verification submitted to Voyager"
    else
        print_warning "$contract verification may have failed or already verified"
    fi
}

# =============================================================================
# PARAMETER VALIDATION
# =============================================================================

print_info "Validating parameters..."

missing_vars=()
[[ -z "${SNCAST_ACCOUNT:-}" ]] && missing_vars+=("SNCAST_ACCOUNT")
[[ -z "${FACTORY_OWNER:-}" ]] && missing_vars+=("FACTORY_OWNER")

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Usage:"
    echo "  export SNCAST_ACCOUNT=<your_sncast_account_name>"
    echo "  export FACTORY_OWNER=<owner_address>"
    echo "  ./scripts/deploy_stream_token_factory.sh"
    exit 1
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

STARKNET_RPC="${STARKNET_RPC:-$DEFAULT_RPC}"
STARKNET_NETWORK="${STARKNET_NETWORK:-mainnet}"
EKUBO_POSITIONS_ADDRESS="${EKUBO_POSITIONS_ADDRESS:-$DEFAULT_EKUBO_POSITIONS}"
EKUBO_CORE_ADDRESS="${EKUBO_CORE_ADDRESS:-$DEFAULT_EKUBO_CORE}"
EKUBO_EXTENSION_ADDRESS="${EKUBO_EXTENSION_ADDRESS:-$DEFAULT_EKUBO_EXTENSION}"
EKUBO_REGISTRY_ADDRESS="${EKUBO_REGISTRY_ADDRESS:-$DEFAULT_EKUBO_REGISTRY}"

# Validate addresses
validate_address "$FACTORY_OWNER" "FACTORY_OWNER"
validate_address "$EKUBO_POSITIONS_ADDRESS" "EKUBO_POSITIONS_ADDRESS"
validate_address "$EKUBO_CORE_ADDRESS" "EKUBO_CORE_ADDRESS"
validate_address "$EKUBO_EXTENSION_ADDRESS" "EKUBO_EXTENSION_ADDRESS"
validate_address "$EKUBO_REGISTRY_ADDRESS" "EKUBO_REGISTRY_ADDRESS"

# =============================================================================
# DISPLAY CONFIGURATION
# =============================================================================

print_info "Deployment Configuration:"
cat << EOF

  Account:         $SNCAST_ACCOUNT
  RPC:             $STARKNET_RPC
  Network:         $STARKNET_NETWORK

  Factory Owner:   $FACTORY_OWNER

  Ekubo Addresses:
    Positions:     $EKUBO_POSITIONS_ADDRESS
    Core:          $EKUBO_CORE_ADDRESS
    Extension:     $EKUBO_EXTENSION_ADDRESS
    Registry:      $EKUBO_REGISTRY_ADDRESS

EOF

# Confirmation prompt
if [[ "${SKIP_CONFIRMATION:-false}" != "true" ]]; then
    read -p "Continue with deployment? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
fi

# =============================================================================
# BUILD
# =============================================================================

print_step "Building contracts..."
cd "$REPO_ROOT"

scarb build -p game_components_presets
scarb build -p game_components_tokenomics

# Verify artifacts exist
for artifact in \
    "target/dev/game_components_presets_StreamToken.contract_class.json" \
    "target/dev/game_components_tokenomics_StreamTokenFactory.contract_class.json"
do
    if [ ! -f "$artifact" ]; then
        print_error "Build artifact not found: $artifact"
        exit 1
    fi
done

print_info "Build successful"

# =============================================================================
# DECLARE CONTRACTS
# =============================================================================

print_step "Declaring StreamToken..."
STREAM_TOKEN_CLASS_HASH=$(declare_contract "game_components_presets" "StreamToken")
STREAM_TOKEN_TX_HASH="${DECLARE_TX_HASH:-}"

print_step "Declaring StreamTokenFactory..."
FACTORY_CLASS_HASH=$(declare_contract "game_components_tokenomics" "StreamTokenFactory")
FACTORY_DECLARE_TX_HASH="${DECLARE_TX_HASH:-}"

# =============================================================================
# VERIFY CONTRACTS
# =============================================================================

print_step "Verifying contracts on Voyager..."
verify_contract "$STREAM_TOKEN_CLASS_HASH" "StreamToken" "game_components_presets"
verify_contract "$FACTORY_CLASS_HASH" "StreamTokenFactory" "game_components_tokenomics"

# =============================================================================
# DEPLOY FACTORY
# =============================================================================

print_step "Deploying StreamTokenFactory..."

CONSTRUCTOR_ARGS="$FACTORY_OWNER, $STREAM_TOKEN_CLASS_HASH, $EKUBO_POSITIONS_ADDRESS, $EKUBO_CORE_ADDRESS, $EKUBO_EXTENSION_ADDRESS, $EKUBO_REGISTRY_ADDRESS"
print_verbose "Constructor args: $CONSTRUCTOR_ARGS"

DEPLOY_OUTPUT=$(sncast --account "$SNCAST_ACCOUNT" \
    deploy \
    --url "$STARKNET_RPC" \
    --class-hash "$FACTORY_CLASS_HASH" \
    --arguments "$CONSTRUCTOR_ARGS" 2>&1) || true

print_verbose "$DEPLOY_OUTPUT"

FACTORY_ADDRESS=$(extract_contract_address "$DEPLOY_OUTPUT")
DEPLOY_TX_HASH=$(extract_transaction_hash "$DEPLOY_OUTPUT")

if [ -z "$FACTORY_ADDRESS" ]; then
    print_error "Failed to deploy StreamTokenFactory"
    print_error "Output: $DEPLOY_OUTPUT"
    exit 1
fi

print_info "StreamTokenFactory deployed at: $FACTORY_ADDRESS"
[ -n "$DEPLOY_TX_HASH" ] && print_info "Transaction: $DEPLOY_TX_HASH"

# =============================================================================
# SAVE DEPLOYMENT INFO
# =============================================================================

DEPLOYMENT_DIR="$REPO_ROOT/deployments"
DEPLOYMENT_FILE="$DEPLOYMENT_DIR/stream_token_factory_$(date +%Y%m%d_%H%M%S).json"
mkdir -p "$DEPLOYMENT_DIR"

cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "$STARKNET_NETWORK",
  "rpc": "$STARKNET_RPC",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stream_token": {
    "class_hash": "$STREAM_TOKEN_CLASS_HASH",
    "declare_tx_hash": "${STREAM_TOKEN_TX_HASH:-null}"
  },
  "stream_token_factory": {
    "address": "$FACTORY_ADDRESS",
    "class_hash": "$FACTORY_CLASS_HASH",
    "declare_tx_hash": "${FACTORY_DECLARE_TX_HASH:-null}",
    "deploy_tx_hash": "${DEPLOY_TX_HASH:-null}",
    "constructor_args": {
      "owner": "$FACTORY_OWNER",
      "stream_token_class_hash": "$STREAM_TOKEN_CLASS_HASH",
      "positions_address": "$EKUBO_POSITIONS_ADDRESS",
      "core_address": "$EKUBO_CORE_ADDRESS",
      "extension_address": "$EKUBO_EXTENSION_ADDRESS",
      "registry_address": "$EKUBO_REGISTRY_ADDRESS"
    }
  }
}
EOF

print_info "Deployment saved to: $DEPLOYMENT_FILE"

# =============================================================================
# SUMMARY
# =============================================================================

cat << EOF

${GREEN}=== DEPLOYMENT SUCCESSFUL ===${NC}

StreamToken:
  Class Hash:  $STREAM_TOKEN_CLASS_HASH

StreamTokenFactory:
  Address:     $FACTORY_ADDRESS
  Class Hash:  $FACTORY_CLASS_HASH
  Owner:       $FACTORY_OWNER

Ekubo Integration:
  Positions:   $EKUBO_POSITIONS_ADDRESS
  Core:        $EKUBO_CORE_ADDRESS
  Extension:   $EKUBO_EXTENSION_ADDRESS
  Registry:    $EKUBO_REGISTRY_ADDRESS

Explorer Links:
  Voyager:     https://voyager.online/contract/$FACTORY_ADDRESS
  Starkscan:   https://starkscan.co/contract/$FACTORY_ADDRESS

To use the factory:
  export STREAM_TOKEN_FACTORY=$FACTORY_ADDRESS

EOF
