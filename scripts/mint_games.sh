#!/bin/bash

# Script to mint multiple test games with various configurations
# Based on the mint function signature in core_token.cairo

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
    required_vars=("STARKNET_ACCOUNT" "STARKNET_RPC" "TOKEN_CONTRACT" "TO_ADDRESS")
else
    required_vars=("STARKNET_NETWORK" "STARKNET_ACCOUNT" "STARKNET_RPC" "STARKNET_PK" "TOKEN_CONTRACT" "TO_ADDRESS")
fi

missing_vars=()

# Debug output for environment variables
print_info "Environment variables loaded:"
echo "  DEPLOY_TO_SLOT: $DEPLOY_TO_SLOT"
echo "  STARKNET_NETWORK: ${STARKNET_NETWORK:-<not set>}"
echo "  STARKNET_ACCOUNT: ${STARKNET_ACCOUNT:-<not set>}"
echo "  STARKNET_RPC: ${STARKNET_RPC:-<not set>}"
echo "  STARKNET_PK: ${STARKNET_PK:+<set>}"
echo "  TOKEN_CONTRACT: ${TOKEN_CONTRACT:-<not set>}"
echo "  TO_ADDRESS: ${TO_ADDRESS:-<not set>}"

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

# Default values for optional parameters
DEFAULT_GAME_ADDRESS="0x0"  # Use 0x0 for None
DEFAULT_PLAYER_NAME=""      # Empty string for None
DEFAULT_SETTINGS_ID="0"     # 0 for None
DEFAULT_START="0"           # 0 for None
DEFAULT_END="0"             # 0 for None
DEFAULT_CONTEXT=""          # Empty for None
DEFAULT_CLIENT_URL=""       # Empty for None
DEFAULT_RENDERER="0x0"      # 0x0 for None
DEFAULT_SOULBOUND="0"       # 0 for false, 1 for true

# Optional addresses (can be set via environment variables)
GAME_ADDRESS="${GAME_ADDRESS:-}"
RENDERER_ADDRESS="${RENDERER_ADDRESS:-}"

# ============================
# DISPLAY CONFIGURATION
# ============================

print_info "Mint Configuration:"
echo "  Deployment Type: $(if [ "$DEPLOY_TO_SLOT" = "true" ]; then echo "Slot"; else echo "Standard"; fi)"
echo "  Network: ${STARKNET_NETWORK:-<not required for Slot>}"
echo "  Account: $STARKNET_ACCOUNT"
echo "  Token Contract: $TOKEN_CONTRACT"
echo "  Mint To Address: $TO_ADDRESS"
echo ""
echo "  Optional Parameters:"
echo "    Game Address: ${GAME_ADDRESS:-<not set>}"
echo "    Renderer Address: ${RENDERER_ADDRESS:-<not set>}"

# Confirm minting
if [ "${SKIP_CONFIRMATION:-false}" != "true" ]; then
    read -p "Continue with minting test games? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Minting cancelled"
        exit 0
    fi
fi

# ============================
# HELPER FUNCTIONS
# ============================

# Function to convert optional parameters to starknet format
# Empty strings and 0x0 addresses are treated as None
format_option() {
    local value=$1
    if [ -z "$value" ] || [ "$value" = "0x0" ] || [ "$value" = "0" ]; then
        echo "1"  # None in Cairo
    else
        echo "0 $value"  # Some(value) in Cairo
    fi
}

# Function to format string as ByteArray
format_bytearray() {
    local str=$1
    if [ -z "$str" ]; then
        echo "1"  # None
    else
        # Convert string to hex bytes and format as ByteArray
        # For simplicity, using the string directly (starkli should handle conversion)
        echo "0 $str"
    fi
}

# Function to format array option (for objective_ids)
format_array_option() {
    local arr=$1
    if [ -z "$arr" ] || [ "$arr" = "0" ]; then
        echo "1"  # None
    else
        # Format as Some(array) - array length followed by elements
        echo "0 $arr"
    fi
}

# Function to format GameContextDetails
format_context() {
    local context=$1
    if [ -z "$context" ]; then
        echo "1"  # None
    else
        # GameContextDetails format: game_id, tournament_id, round_id
        echo "0 $context"
    fi
}

# Function to mint a single game
mint_game() {
    local game_address=${1:-${GAME_ADDRESS:-$DEFAULT_GAME_ADDRESS}}
    local player_name=${2:-$DEFAULT_PLAYER_NAME}
    local settings_id=${3:-$DEFAULT_SETTINGS_ID}
    local start=${4:-$DEFAULT_START}
    local end=${5:-$DEFAULT_END}
    local objective_ids=${6:-"0"}  # Format: "length id1 id2 ..."
    local context=${7:-$DEFAULT_CONTEXT}  # Format: "game_id tournament_id round_id"
    local client_url=${8:-$DEFAULT_CLIENT_URL}
    local renderer=${9:-${RENDERER_ADDRESS:-$DEFAULT_RENDERER}}
    local soulbound=${10:-$DEFAULT_SOULBOUND}
    
    echo "Minting game with parameters:"
    echo "  Game Address: $game_address"
    echo "  Player Name: $player_name"
    echo "  Settings ID: $settings_id"
    echo "  Start: $start"
    echo "  End: $end"
    echo "  Objectives: $objective_ids"
    echo "  Context: $context"
    echo "  Client URL: $client_url"
    echo "  Renderer: $renderer"
    echo "  To: $TO_ADDRESS"
    echo "  Soulbound: $soulbound"
    
    # Build the invoke command
    local CMD="starkli invoke"
    CMD="$CMD --account $STARKNET_ACCOUNT"
    CMD="$CMD --rpc $STARKNET_RPC"
    
    if [ "$DEPLOY_TO_SLOT" != "true" ] && [ -n "$STARKNET_PK" ]; then
        CMD="$CMD --private-key $STARKNET_PK"
    fi
    
    CMD="$CMD --watch"
    CMD="$CMD $TOKEN_CONTRACT"
    CMD="$CMD mint"
    
    # Add parameters in order
    CMD="$CMD $(format_option $game_address)"
    CMD="$CMD $(format_bytearray "$player_name")"
    CMD="$CMD $(format_option $settings_id)"
    CMD="$CMD $(format_option $start)"
    CMD="$CMD $(format_option $end)"
    CMD="$CMD $(format_array_option "$objective_ids")"
    CMD="$CMD $(format_context "$context")"
    CMD="$CMD $(format_bytearray "$client_url")"
    CMD="$CMD $(format_option $renderer)"
    CMD="$CMD $TO_ADDRESS"
    CMD="$CMD $soulbound"
    
    echo "Executing: $CMD"
    eval $CMD
    
    if [ $? -eq 0 ]; then
        print_info "Successfully minted game!"
    else
        print_error "Failed to mint game"
        return 1
    fi
    echo "---"
}

# ============================
# MAIN EXECUTION
# ============================

print_info "Starting batch mint of test games..."
echo "Token Contract: $TOKEN_CONTRACT"
echo "Minting to: $TO_ADDRESS"
echo "---"

# # Example 1: Basic game with no optional parameters
# echo
# print_info "Test 1: Basic game (no optional parameters)"
# mint_game

# # Example 2: Game with player name and settings
# echo
# print_info "Test 2: Game with player name and settings"
# mint_game \
#     "" \
#     "bytearray:str:Player_One" \
#     "1" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "0"

# # Example 3: Time-limited game (with start and end times)
CURRENT_TIME=$(date +%s)
START_TIME=$CURRENT_TIME
END_TIME=$((CURRENT_TIME + 3600))  # 1 hour from now

# echo
# print_info "Test 3: Time-limited game"
# mint_game \
#     "" \
#     "bytearray:str:Timed_Player" \
#     "2" \
#     "$START_TIME" \
#     "$END_TIME" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "0"

# # Example 4: Game with objectives
# echo
# print_info "Test 4: Game with objectives"
# mint_game \
#     "" \
#     "bytearray:str:Objective_Hunter" \
#     "1" \
#     "" \
#     "" \
#     "3 1 2 3" \
#     "" \
#     "" \
#     "" \
#     "0"

#         pub name: ByteArray,
#     pub description: ByteArray,
#     pub id: Option<u32>,
#     pub context: Span<GameContext>,

# # Example 5: Game with context (tournament)
# echo
# print_info "Test 5: Tournament game with context"
# mint_game \
#     "" \
#     "bytearray:str:Tournament_Player" \
#     "1" \
#     "" \
#     "" \
#     "2 1 5" \
#     "bytearray:str:Test_Name bytearray:str:Test_Description 0 1 1 bytearray:str:Tournament_Id bytearray:str:1" \
#     "" \
#     "" \
#     "0"

# # Example 6: Game with client URL and renderer
# echo
# print_info "Test 6: Game with client URL and custom renderer"
# mint_game \
#     "" \
#     "bytearray:str:Custom_Player" \
#     "1" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "bytearray:str:https://game.example.com" \
#     "${RENDERER_ADDRESS:-0x123456789abcdef}" \
#     "0"

# # Example 7: Soulbound game
# echo
# print_info "Test 7: Soulbound game"
# mint_game \
#     "" \
#     "bytearray:str:Soulbound_Player" \
#     "1" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "" \
#     "1"

# # Example 8: Death Mountain game
# echo
# print_info "Test 8: Full-featured game with all parameters"
# starkli invoke \
#     --account $STARKNET_ACCOUNT \
#     --rpc $STARKNET_RPC \
#     --watch \
#     $GAME_ADDRESS \
#     mint_game \
#     $(format_bytearray "bytearray:str:Death_Mountain_Player") \
#     $(format_option "") \
#     $(format_option "$START_TIME") \
#     $(format_option "$END_TIME") \
#     $(format_array_option "4 10 20 30 40") \
#     $(format_context "") \
#     $(format_bytearray "bytearray:str:https://elite.game.com") \
#     $(format_option "") \
#     $TO_ADDRESS \
#     $(format_option "0")

# Example 9: Death Mountain create setting
echo
print_info "Test 8: Full-featured game with all parameters"
starkli invoke \
    --account $STARKNET_ACCOUNT \
    --rpc $STARKNET_RPC \
    --watch \
    $GAME_ADDRESS \
    mint_game \
    $(format_bytearray "bytearray:str:Death_Mountain_Player") \
    $(format_option "") \
    $(format_option "$START_TIME") \
    $(format_option "$END_TIME") \
    $(format_array_option "4 10 20 30 40") \
    $(format_context "") \
    $(format_bytearray "bytearray:str:https://elite.game.com") \
    $(format_option "") \
    $TO_ADDRESS \
    $(format_option "0")

# ============================
# COMPLETION SUMMARY
# ============================

echo
print_info "=== BATCH MINTING COMPLETE ==="
echo
echo "Minted 8 test games with various configurations:"
echo "  1. Basic game (minimal parameters)"
echo "  2. Game with player name and settings"
echo "  3. Time-limited game ($START_TIME to $END_TIME)"
echo "  4. Game with 3 objectives"
echo "  5. Tournament game with context"
echo "  6. Game with client URL and renderer"
echo "  7. Soulbound game (non-transferable)"
echo "  8. Full-featured game with all parameters"
echo
echo "All games minted to: $TO_ADDRESS"
echo "On token contract: $TOKEN_CONTRACT"