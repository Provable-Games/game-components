#!/bin/bash

# Airlock Deployment Script
# Deploys the Airlock liquidity bootstrapping factory contract

set -euo pipefail

# ============================
# STARKLI VERSION CHECK
# ============================

STARKLI_VERSION=$(starkli --version | cut -d' ' -f1)
echo "Detected starkli version: $STARKLI_VERSION"

# Check if version is 0.3.x for RPC compatibility
if [[ ! "$STARKLI_VERSION" =~ ^0\.3\. ]]; then
    echo "WARNING: starkli version $STARKLI_VERSION may have RPC compatibility issues with Sepolia."
    echo "Consider running: starkliup -v 0.3.8"
    echo ""
fi

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
    echo "Loaded environment variables from .env file"
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

# Check if required environment variables are set
print_info "Checking environment variables..."
required_vars=("STARKNET_NETWORK" "STARKNET_ACCOUNT" "STARKNET_RPC" "STARKNET_PK")
missing_vars=()

# Debug output for environment variables
print_info "Environment variables loaded:"
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

# Check that private key is set
if [ -z "${STARKNET_PK:-}" ]; then
    print_error "STARKNET_PK environment variable is not set"
    exit 1
fi

print_warning "Using private key (insecure for production)"

# ============================
# CONFIGURATION PARAMETERS
# ============================

# Deployment Parameters
# Allow owner to be overridden by environment variable, default to deployer account
OWNER_ADDRESS="${AIRLOCK_OWNER:-$STARKNET_ACCOUNT}"

# ============================
# DISPLAY CONFIGURATION
# ============================

print_info "Airlock Deployment Configuration:"
echo "  Network: $STARKNET_NETWORK"
echo "  Account: $STARKNET_ACCOUNT"
echo "  Owner Address: $OWNER_ADDRESS"

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

print_info "Building Airlock contract..."
scarb build

if [ ! -f "target/dev/beedle_Airlock.contract_class.json" ]; then
    print_error "Contract build failed or contract file not found"
    exit 1
fi

# ============================
# DECLARE CONTRACT
# ============================

print_info "Declaring Airlock contract..."
DECLARE_OUTPUT=$(starkli declare --account $STARKNET_ACCOUNT --watch target/dev/beedle_Airlock.contract_class.json --private-key $STARKNET_PK 2>&1)

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
# DEPLOY CONTRACT
# ============================

print_info "Deploying Airlock contract..."

# Execute deployment
print_info "Executing deployment with starkli..."
print_info "Command: starkli deploy"
print_info "Class hash: $CLASS_HASH"
print_info "Owner: $OWNER_ADDRESS"

# Check if we should use ETH or STRK for fees
FEE_TOKEN_FLAG=""
if [ "${USE_ETH_FEES:-false}" == "true" ]; then
    FEE_TOKEN_FLAG="--eth"
    print_warning "Using ETH for transaction fees (deprecated)"
else
    FEE_TOKEN_FLAG="--strk"
    print_info "Using STRK for transaction fees"
fi

# Deploy with --watch flag
CONTRACT_ADDRESS=$(starkli deploy \
    --account $STARKNET_ACCOUNT \
    --private-key $STARKNET_PK \
    $FEE_TOKEN_FLAG \
    --watch \
    $CLASS_HASH \
    $OWNER_ADDRESS 2>&1 | tee >(cat >&2) | grep -oE '0x[0-9a-fA-F]{64}' | tail -1)

if [ -z "$CONTRACT_ADDRESS" ]; then
    print_error "Failed to deploy contract"
    exit 1
fi

print_info "Airlock contract deployed at address: $CONTRACT_ADDRESS"

# ============================
# SAVE DEPLOYMENT INFO
# ============================

DEPLOYMENT_FILE="deployments/airlock_$(date +%Y%m%d_%H%M%S).json"
mkdir -p deployments

cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "$STARKNET_NETWORK",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contract_address": "$CONTRACT_ADDRESS",
  "class_hash": "$CLASS_HASH",
  "parameters": {
    "owner": "$OWNER_ADDRESS"
  }
}
EOF

print_info "Deployment info saved to: $DEPLOYMENT_FILE"

# ============================
# DEPLOYMENT SUMMARY
# ============================

echo
print_info "=== AIRLOCK DEPLOYMENT SUCCESSFUL ==="
echo "Contract Address: $CONTRACT_ADDRESS"
echo "Class Hash: $CLASS_HASH"
echo "Owner: $OWNER_ADDRESS"
echo
echo "Next steps:"
echo "1. Set module states for your token factory, governance factory, pool initializer, and liquidity migrator contracts"
echo "2. Users can now create new tokens through the Airlock factory"
echo "3. Monitor fee accumulation and collect protocol/integrator fees as needed"
echo
echo "To interact with the contract:"
echo "  export AIRLOCK_CONTRACT=$CONTRACT_ADDRESS"
echo
echo "Example: Set module states (replace with your module addresses):"
echo "  starkli invoke --account \$STARKNET_ACCOUNT --watch \$AIRLOCK_CONTRACT set_module_state \\"
echo "    [0xTOKEN_FACTORY,0xGOVERNANCE_FACTORY,0xPOOL_INIT,0xLIQ_MIGRATOR] \\"
echo "    [1,2,3,4] --private-key \$STARKNET_PK"