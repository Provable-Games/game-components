#!/bin/bash

# Minigame Mock Contract Deployment Script
# Deploys the MinigameStarknetMock from the test_starknet package

set -euo pipefail

# ============================
# STARKLI VERSION CHECK
# ============================

STARKLI_VERSION=$(starkli --version | cut -d' ' -f1)
echo "Detected starkli version: $STARKLI_VERSION"

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

# Game Parameters
GAME_CREATOR="${TO_ADDRESS:-0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec}"
GAME_NAME="${GAME_NAME:-TestMinigame}"
GAME_DESCRIPTION="${GAME_DESCRIPTION:-A test minigame for development}"
GAME_DEVELOPER="${GAME_DEVELOPER:-TestDeveloper}"
GAME_PUBLISHER="${GAME_PUBLISHER:-TestPublisher}"
GAME_GENRE="${GAME_GENRE:-Action}"
GAME_IMAGE="${GAME_IMAGE:-https://api.game.com/image.png}"
# Remove # from color as it might cause issues with starkli
GAME_COLOR="${GAME_COLOR:-FF5733}"
CLIENT_URL="${CLIENT_URL:-https://game.example.com}"

# Contract addresses (can be set via environment variables)
MINIGAME_TOKEN_ADDRESS="${MINIGAME_TOKEN_ADDRESS:-${TOKEN_CONTRACT:-}}"
RENDERER_ADDRESS="${RENDERER_ADDRESS:-}"
SETTINGS_ADDRESS="${SETTINGS_ADDRESS:-}"
OBJECTIVES_ADDRESS="${OBJECTIVES_ADDRESS:-}"

# ============================
# DISPLAY CONFIGURATION
# ============================

print_info "Deployment Configuration:"
echo "  Deployment Type: $(if [ "$DEPLOY_TO_SLOT" = "true" ]; then echo "Slot"; else echo "Standard"; fi)"
echo "  Network: ${STARKNET_NETWORK:-<not required for Slot>}"
echo "  Account: $STARKNET_ACCOUNT"
echo ""
echo "  Game Parameters:"
echo "    Creator: $GAME_CREATOR"
echo "    Name: $GAME_NAME"
echo "    Description: $GAME_DESCRIPTION"
echo "    Developer: $GAME_DEVELOPER"
echo "    Publisher: $GAME_PUBLISHER"
echo "    Genre: $GAME_GENRE"
echo "    Image: $GAME_IMAGE"
echo "    Color: $GAME_COLOR"
echo "    Client URL: $CLIENT_URL"
echo ""
echo "  Required Address:"
echo "    Minigame Token Address: ${MINIGAME_TOKEN_ADDRESS:-<MUST BE SET>}"
echo ""
echo "  Optional Addresses:"
echo "    Renderer Address: ${RENDERER_ADDRESS:-<not set>}"
echo "    Settings Address: ${SETTINGS_ADDRESS:-<not set>}"
echo "    Objectives Address: ${OBJECTIVES_ADDRESS:-<not set>}"

# Check that minigame token address is set
if [ -z "$MINIGAME_TOKEN_ADDRESS" ]; then
    print_error "MINIGAME_TOKEN_ADDRESS must be set"
    echo "Deploy a token contract first using deploy_optimized_token.sh"
    exit 1
fi

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
# BUILD CONTRACTS
# ============================

print_info "Building contracts..."
cd packages/test_starknet
scarb build
# Return to scripts directory
cd ../..

if [ ! -f "target/dev/game_components_test_starknet_minigame_starknet_mock.contract_class.json" ]; then
    print_error "Contract build failed or contract file not found"
    print_error "Expected: target/dev/game_components_test_starknet_minigame_starknet_mock.contract_class.json"
    echo "Available contract files:"
    ls -la target/dev/*.contract_class.json 2>/dev/null || echo "No contract files found"
    exit 1
fi

# ============================
# DECLARE CONTRACT
# ============================

print_info "Declaring Minigame Mock contract..."

# Build declare command based on deployment type
CONTRACT_PATH="target/dev/game_components_test_starknet_minigame_starknet_mock.contract_class.json"
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    DECLARE_OUTPUT=$(starkli declare --account $STARKNET_ACCOUNT --rpc $STARKNET_RPC --watch "$CONTRACT_PATH" 2>&1)
else
    DECLARE_OUTPUT=$(starkli declare --account $STARKNET_ACCOUNT --rpc $STARKNET_RPC --watch "$CONTRACT_PATH" --private-key $STARKNET_PK 2>&1)
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

# The minigame mock doesn't have a traditional constructor, it uses initializer
# So we deploy with no constructor args and then call initializer

# ============================
# DEPLOY CONTRACT
# ============================

print_info "Deploying Minigame Mock contract..."

# Execute deployment
print_info "Executing deployment with starkli..."
print_info "Command: starkli deploy"
print_info "Class hash: $CLASS_HASH"

# Deploy with no constructor arguments
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    CONTRACT_ADDRESS=$(starkli deploy \
        --account $STARKNET_ACCOUNT \
        --rpc $STARKNET_RPC \
        --watch \
        $CLASS_HASH \
        2>&1 | tee >(cat >&2) | grep -oE '0x[0-9a-fA-F]{64}' | tail -1)
else
    CONTRACT_ADDRESS=$(starkli deploy \
        --account $STARKNET_ACCOUNT \
        --rpc $STARKNET_RPC \
        --private-key $STARKNET_PK \
        --watch \
        $CLASS_HASH \
        2>&1 | tee >(cat >&2) | grep -oE '0x[0-9a-fA-F]{64}' | tail -1)
fi

if [ -z "$CONTRACT_ADDRESS" ]; then
    print_error "Failed to deploy contract"
    exit 1
fi

print_info "Minigame Mock contract deployed at address: $CONTRACT_ADDRESS"

# ============================
# INITIALIZE CONTRACT
# ============================

print_info "Initializing Minigame Mock contract..."

# Prepare initializer arguments
# For ByteArray parameters in Cairo, starkli expects bytearray:str: format
GAME_NAME_ARG="bytearray:str:$GAME_NAME"
GAME_DESCRIPTION_ARG="bytearray:str:$GAME_DESCRIPTION"
GAME_DEVELOPER_ARG="bytearray:str:$GAME_DEVELOPER"
GAME_PUBLISHER_ARG="bytearray:str:$GAME_PUBLISHER"
GAME_GENRE_ARG="bytearray:str:$GAME_GENRE"
GAME_IMAGE_ARG="bytearray:str:$GAME_IMAGE"

# Optional parameters - we need to handle them differently
# For None, just use 1. For Some, we need to pass multiple arguments
if [ -n "$GAME_COLOR" ]; then
    GAME_COLOR_ARG_1="0"
    GAME_COLOR_ARG_2="bytearray:str:$GAME_COLOR"
else
    GAME_COLOR_ARG_1="1"
    GAME_COLOR_ARG_2=""
fi

if [ -n "$CLIENT_URL" ]; then
    CLIENT_URL_ARG_1="0"
    CLIENT_URL_ARG_2="bytearray:str:$CLIENT_URL"
else
    CLIENT_URL_ARG_1="1"
    CLIENT_URL_ARG_2=""
fi

if [ -n "$RENDERER_ADDRESS" ]; then
    RENDERER_ARG_1="0"
    RENDERER_ARG_2="$RENDERER_ADDRESS"
else
    RENDERER_ARG_1="1"
    RENDERER_ARG_2=""
fi

if [ -n "$SETTINGS_ADDRESS" ]; then
    SETTINGS_ARG_1="0"
    SETTINGS_ARG_2="$SETTINGS_ADDRESS"
else
    SETTINGS_ARG_1="1"
    SETTINGS_ARG_2=""
fi

if [ -n "$OBJECTIVES_ADDRESS" ]; then
    OBJECTIVES_ARG_1="0"
    OBJECTIVES_ARG_2="$OBJECTIVES_ADDRESS"
else
    OBJECTIVES_ARG_1="1"
    OBJECTIVES_ARG_2=""
fi

# Debug: Print the initialization command
print_info "Initialization parameters:"
echo "  Game Creator: $GAME_CREATOR"
echo "  Token Address: $MINIGAME_TOKEN_ADDRESS"
echo "  Game Color: ${GAME_COLOR_ARG_2:-None}"
echo "  Client URL: ${CLIENT_URL_ARG_2:-None}"
echo "  Renderer: ${RENDERER_ARG_2:-None}"
echo "  Settings: ${SETTINGS_ARG_2:-None}"
echo "  Objectives: ${OBJECTIVES_ARG_2:-None}"

# Call initializer
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    print_info "Executing initialization command..."
    starkli invoke \
        --account $STARKNET_ACCOUNT \
        --rpc $STARKNET_RPC \
        --watch \
        $CONTRACT_ADDRESS \
        initializer \
        $GAME_CREATOR \
        "$GAME_NAME_ARG" \
        "$GAME_DESCRIPTION_ARG" \
        "$GAME_DEVELOPER_ARG" \
        "$GAME_PUBLISHER_ARG" \
        "$GAME_GENRE_ARG" \
        "$GAME_IMAGE_ARG" \
        $GAME_COLOR_ARG_1 ${GAME_COLOR_ARG_2:+"$GAME_COLOR_ARG_2"} \
        $CLIENT_URL_ARG_1 ${CLIENT_URL_ARG_2:+"$CLIENT_URL_ARG_2"} \
        $RENDERER_ARG_1 ${RENDERER_ARG_2:+$RENDERER_ARG_2} \
        $SETTINGS_ARG_1 ${SETTINGS_ARG_2:+$SETTINGS_ARG_2} \
        $OBJECTIVES_ARG_1 ${OBJECTIVES_ARG_2:+$OBJECTIVES_ARG_2} \
        $MINIGAME_TOKEN_ADDRESS
    INIT_STATUS=$?
else
    print_info "Executing initialization command..."
    starkli invoke \
        --account $STARKNET_ACCOUNT \
        --rpc $STARKNET_RPC \
        --private-key $STARKNET_PK \
        --watch \
        $CONTRACT_ADDRESS \
        initializer \
        $GAME_CREATOR \
        "$GAME_NAME_ARG" \
        "$GAME_DESCRIPTION_ARG" \
        "$GAME_DEVELOPER_ARG" \
        "$GAME_PUBLISHER_ARG" \
        "$GAME_GENRE_ARG" \
        "$GAME_IMAGE_ARG" \
        $GAME_COLOR_ARG_1 ${GAME_COLOR_ARG_2:+"$GAME_COLOR_ARG_2"} \
        $CLIENT_URL_ARG_1 ${CLIENT_URL_ARG_2:+"$CLIENT_URL_ARG_2"} \
        $RENDERER_ARG_1 ${RENDERER_ARG_2:+$RENDERER_ARG_2} \
        $SETTINGS_ARG_1 ${SETTINGS_ARG_2:+$SETTINGS_ARG_2} \
        $OBJECTIVES_ARG_1 ${OBJECTIVES_ARG_2:+$OBJECTIVES_ARG_2} \
        $MINIGAME_TOKEN_ADDRESS
    INIT_STATUS=$?
fi

if [ $INIT_STATUS -eq 0 ]; then
    print_info "Contract initialized successfully"
else
    print_error "Failed to initialize contract"
    exit 1
fi

# ============================
# SAVE DEPLOYMENT INFO
# ============================

DEPLOYMENT_FILE="deployments/minigame_mock_$(date +%Y%m%d_%H%M%S).json"
mkdir -p deployments

cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "${STARKNET_NETWORK:-slot}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "minigame_mock_contract": {
    "address": "$CONTRACT_ADDRESS",
    "class_hash": "$CLASS_HASH",
    "parameters": {
      "game_creator": "$GAME_CREATOR",
      "game_name": "$GAME_NAME",
      "game_description": "$GAME_DESCRIPTION",
      "game_developer": "$GAME_DEVELOPER",
      "game_publisher": "$GAME_PUBLISHER",
      "game_genre": "$GAME_GENRE",
      "game_image": "$GAME_IMAGE",
      "game_color": "${GAME_COLOR:-null}",
      "client_url": "${CLIENT_URL:-null}",
      "renderer_address": "${RENDERER_ADDRESS:-null}",
      "settings_address": "${SETTINGS_ADDRESS:-null}",
      "objectives_address": "${OBJECTIVES_ADDRESS:-null}",
      "minigame_token_address": "$MINIGAME_TOKEN_ADDRESS"
    }
  }
}
EOF

print_info "Deployment info saved to: $DEPLOYMENT_FILE"

# ============================
# CREATE TEST DATA (OPTIONAL)
# ============================

if [ "${CREATE_TEST_DATA:-false}" = "true" ]; then
    print_info "Creating test settings and objectives..."
    
    # Create some test settings
    print_info "Creating Easy difficulty setting..."
    if [ "$DEPLOY_TO_SLOT" = "true" ]; then
        starkli invoke \
            --account $STARKNET_ACCOUNT \
            --rpc $STARKNET_RPC \
            --watch \
            $CONTRACT_ADDRESS \
            create_settings_difficulty \
            "bytearray:str:Easy Mode" \
            "bytearray:str:For beginners" \
            1
    else
        starkli invoke \
            --account $STARKNET_ACCOUNT \
            --rpc $STARKNET_RPC \
            --private-key $STARKNET_PK \
            --watch \
            $CONTRACT_ADDRESS \
            create_settings_difficulty \
            "bytearray:str:Easy Mode" \
            "bytearray:str:For beginners" \
            1
    fi
    
    print_info "Creating Medium difficulty setting..."
    if [ "$DEPLOY_TO_SLOT" = "true" ]; then
        starkli invoke \
            --account $STARKNET_ACCOUNT \
            --rpc $STARKNET_RPC \
            --watch \
            $CONTRACT_ADDRESS \
            create_settings_difficulty \
            "bytearray:str:Medium Mode" \
            "bytearray:str:Standard difficulty" \
            5
    else
        starkli invoke \
            --account $STARKNET_ACCOUNT \
            --rpc $STARKNET_RPC \
            --private-key $STARKNET_PK \
            --watch \
            $CONTRACT_ADDRESS \
            create_settings_difficulty \
            "bytearray:str:Medium Mode" \
            "bytearray:str:Standard difficulty" \
            5
    fi
    
    # Create some test objectives
    print_info "Creating score objectives..."
    for score in 100 500 1000; do
        print_info "Creating objective: Score > $score"
        if [ "$DEPLOY_TO_SLOT" = "true" ]; then
            starkli invoke \
                --account $STARKNET_ACCOUNT \
                --rpc $STARKNET_RPC \
                --watch \
                $CONTRACT_ADDRESS \
                create_objective_score \
                $score
        else
            starkli invoke \
                --account $STARKNET_ACCOUNT \
                --rpc $STARKNET_RPC \
                --private-key $STARKNET_PK \
                --watch \
                $CONTRACT_ADDRESS \
                create_objective_score \
                $score
        fi
    done
    
    print_info "Test data created successfully"
fi

# ============================
# DEPLOYMENT SUMMARY
# ============================

echo
print_info "=== DEPLOYMENT SUCCESSFUL ==="
echo
echo "Minigame Mock Contract:"
echo "  Address: $CONTRACT_ADDRESS"
echo "  Class Hash: $CLASS_HASH"
echo "  Game Name: $GAME_NAME"
echo "  Token Address: $MINIGAME_TOKEN_ADDRESS"
echo

echo "Next steps:"
echo "1. Deploy a token contract if not already done"
echo "2. Mint game tokens using the token contract"
echo "3. Start games, update scores, and end games"
echo "4. Create settings and objectives as needed"
echo

echo "To interact with the contract:"
echo "  export MINIGAME_CONTRACT=$CONTRACT_ADDRESS"
echo

echo "Example commands:"
echo ""
echo "# Create a setting (difficulty level 3)"
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  create_settings_difficulty \\"
    echo "  bytearray:str:\"Hard Mode\" \\"
    echo "  bytearray:str:\"For experienced players\" \\"
    echo "  3"
else
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  create_settings_difficulty \\"
    echo "  bytearray:str:\"Hard Mode\" \\"
    echo "  bytearray:str:\"For experienced players\" \\"
    echo "  3 \\"
    echo "  --private-key \$STARKNET_PK"
fi
echo ""
echo "# Create an objective (score > 250)"
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  create_objective_score 250"
else
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  create_objective_score 250 --private-key \$STARKNET_PK"
fi
echo ""
echo "# Start a game (token_id: 1)"
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  start_game 1"
else
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  start_game 1 --private-key \$STARKNET_PK"
fi
echo ""
echo "# End a game with score (token_id: 1, score: 300)"
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  end_game 1 300"
else
    echo "starkli invoke --account \$STARKNET_ACCOUNT --watch \$MINIGAME_CONTRACT \\"
    echo "  end_game 1 300 --private-key \$STARKNET_PK"
fi

# Create test data automatically if requested
if [ "${CREATE_TEST_DATA:-false}" = "true" ]; then
    echo ""
    echo "Test data has been created:"
    echo "  - 2 difficulty settings (Easy: 1, Medium: 5)"
    echo "  - 3 score objectives (100, 500, 1000)"
fi