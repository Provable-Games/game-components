#!/bin/bash

# =============================================================================
# Stream Token Creation Script
# =============================================================================
#
# Creates a new autonomous ERC20 token with TWAMM distribution via Ekubo
# using the StreamTokenFactory contract.
#
# DESIGN DECISIONS:
#   - All token amounts are assumed to be 18 decimals
#   - Config values are human-readable (e.g., "1000000" = 1 million tokens)
#   - The script automatically converts to wei (multiplies by 10^18)
#   - Initial tick is calculated automatically by the StreamToken contract
#
# PRICE CALCULATION:
#   The initial pool price is derived from the liquidity amounts you provide:
#     price = paired_token_amount / stream_token_amount
#
#   Example: 100,000 stream tokens + 1,000 paired tokens = price of 0.01 paired per stream token
#
#   The StreamToken contract handles tick calculation internally using Ekubo's
#   sqrt_ratio_to_tick utility, correctly accounting for token ordering.
#
# Prerequisites:
#   - StreamTokenFactory must be deployed (use deploy_stream_token_factory.sh first)
#   - sncast account configured (sncast account create/import)
#   - Sufficient paired tokens (e.g., ETH, USDC) in your account
#   - jq installed for JSON parsing
#
# Required Environment Variables:
#   SNCAST_ACCOUNT         - Name of the sncast account to use
#   STREAM_TOKEN_FACTORY   - Factory contract address
#
# Optional Environment Variables:
#   STARKNET_RPC           - RPC endpoint (default: Cartridge mainnet)
#   SKIP_CONFIRMATION      - Set to "true" to skip confirmation prompt
#   VERBOSE                - Set to "true" for detailed output
#
# Usage:
#   export SNCAST_ACCOUNT=myaccount
#   export STREAM_TOKEN_FACTORY=0x...
#   ./scripts/create_stream_token.sh config.json
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTS
# =============================================================================

readonly DEFAULT_RPC="https://api.cartridge.gg/x/starknet/mainnet/rpc/v0_10"
readonly DECIMALS=18
readonly WEI_MULTIPLIER="1000000000000000000"  # 10^18

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
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

print_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_step()    { echo -e "${BLUE}[STEP]${NC} $1"; }
print_verbose() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $1" || true; }

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if required tools are installed
check_dependencies() {
    local missing=()

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    if ! command -v sncast &> /dev/null; then
        missing+=("sncast (install via: curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh)")
    fi
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    if ! command -v xxd &> /dev/null; then
        missing+=("xxd (part of vim or xxd package)")
    fi
    if ! command -v bc &> /dev/null; then
        missing+=("bc")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install on macOS: brew install jq xxd bc"
        echo "Install on Ubuntu: apt install jq xxd bc curl"
        exit 1
    fi
}

# Validate that a string looks like a Starknet address (0x followed by hex)
validate_address() {
    local address="$1"
    local name="$2"
    if [[ ! "$address" =~ ^0x[0-9a-fA-F]+$ ]]; then
        print_error "Invalid $name: '$address' (must be hex starting with 0x)"
        return 1
    fi
}

# Convert human-readable amount to wei (18 decimals)
# Input: "1000000" (1 million tokens)
# Output: "1000000000000000000000000" (1 million * 10^18)
to_wei() {
    local amount="$1"
    # Remove any existing decimal point and handle integer input
    if [[ "$amount" == *"."* ]]; then
        print_error "Decimal amounts not supported. Use integer values (e.g., '1' not '1.0')"
        exit 1
    fi
    echo "${amount}${WEI_MULTIPLIER:1}"  # Append 18 zeros
}


# =============================================================================
# EKUBO TWAMM TIME VALIDATION
# =============================================================================
# Ekubo requires TWAMM order times to be aligned to specific intervals.
# The alignment depends on how far the time is from "now":
#   - step = 16^(max(1, floor(log_16(time - now))))
#
# This means:
#   - Times within 16 seconds of now: must be multiples of 16
#   - Times 16-256 seconds away: must be multiples of 16
#   - Times 256-4096 seconds away: must be multiples of 256
#   - Times 4096-65536 seconds away: must be multiples of 4096
#   - etc. (powers of 16)
#
# Reference: ekubo/src/math/time.cairo

readonly TIME_SPACING_SIZE=16

# Calculate the required time step for a given timestamp
# Based on Ekubo's is_time_valid logic
get_time_step() {
    local now="$1"
    local time="$2"

    awk -v now="$now" -v time="$time" 'BEGIN {
        TIME_SPACING_SIZE = 16;
        LOG_SCALE_FACTOR = 4;

        if (time <= now + TIME_SPACING_SIZE) {
            print TIME_SPACING_SIZE;
            exit;
        }

        diff = time - now;

        # Calculate msb (most significant bit position)
        # msb = floor(log2(diff))
        msb = 0;
        temp = diff;
        while (temp > 1) {
            temp = int(temp / 2);
            msb++;
        }

        # step = 2^(LOG_SCALE_FACTOR * floor(msb / LOG_SCALE_FACTOR))
        # This is equivalent to 16^floor(log_16(diff))
        exponent = LOG_SCALE_FACTOR * int(msb / LOG_SCALE_FACTOR);
        step = 1;
        for (i = 0; i < exponent; i++) {
            step *= 2;
        }

        print step;
    }'
}

# Check if a timestamp is valid for TWAMM
is_time_valid() {
    local now="$1"
    local time="$2"

    local step
    step=$(get_time_step "$now" "$time")

    if [ $((time % step)) -eq 0 ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Get the next valid timestamp (rounds up to next valid time)
get_next_valid_time() {
    local now="$1"
    local time="$2"

    awk -v now="$now" -v time="$time" 'BEGIN {
        TIME_SPACING_SIZE = 16;
        LOG_SCALE_FACTOR = 4;

        # For start_time=0, it means "start immediately" - keep as 0
        if (time == 0) {
            print 0;
            exit;
        }

        if (time <= now + TIME_SPACING_SIZE) {
            step = TIME_SPACING_SIZE;
        } else {
            diff = time - now;
            msb = 0;
            temp = diff;
            while (temp > 1) {
                temp = int(temp / 2);
                msb++;
            }
            exponent = LOG_SCALE_FACTOR * int(msb / LOG_SCALE_FACTOR);
            step = 1;
            for (i = 0; i < exponent; i++) {
                step *= 2;
            }
        }

        # Round up to next multiple of step
        if (time % step == 0) {
            print time;
        } else {
            print (int(time / step) + 1) * step;
        }
    }'
}

# Validate all distribution order times
# Echoes "valid" or "invalid" to stdout; diagnostic messages go to stderr
validate_order_times() {
    local config="$1"
    local now="$2"
    local count
    local all_valid=true

    count=$(echo "$config" | jq '.distribution_orders | length')

    for i in $(seq 0 $((count - 1))); do
        local start_time end_time
        start_time=$(echo "$config" | jq -r ".distribution_orders[$i].start_time")
        end_time=$(echo "$config" | jq -r ".distribution_orders[$i].end_time")

        # Validate start_time (0 means "start immediately" - always valid)
        if [ "$start_time" -ne 0 ]; then
            local start_valid
            start_valid=$(is_time_valid "$now" "$start_time")
            if [ "$start_valid" != "true" ]; then
                local next_start
                next_start=$(get_next_valid_time "$now" "$start_time")
                print_error "Order $((i+1)) start_time $start_time is not TWAMM-aligned"
                echo "         Next valid start_time: $next_start" >&2
                echo "         ($(date -d "@$next_start" 2>/dev/null || date -r "$next_start" 2>/dev/null || echo "timestamp: $next_start"))" >&2
                all_valid=false
            fi
        fi

        # Validate end_time (required, cannot be 0)
        if [ "$end_time" -eq 0 ]; then
            print_error "Order $((i+1)) end_time cannot be 0"
            all_valid=false
        else
            local end_valid
            end_valid=$(is_time_valid "$now" "$end_time")
            if [ "$end_valid" != "true" ]; then
                local next_end
                next_end=$(get_next_valid_time "$now" "$end_time")
                print_error "Order $((i+1)) end_time $end_time is not TWAMM-aligned"
                echo "         Next valid end_time: $next_end" >&2
                echo "         ($(date -d "@$next_end" 2>/dev/null || date -r "$next_end" 2>/dev/null || echo "timestamp: $next_end"))" >&2
                all_valid=false
            fi
        fi

        # Check that end_time > start_time (or start_time is 0)
        if [ "$start_time" -ne 0 ] && [ "$end_time" -le "$start_time" ]; then
            print_error "Order $((i+1)) end_time ($end_time) must be greater than start_time ($start_time)"
            all_valid=false
        fi
    done

    if [ "$all_valid" = "true" ]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

# Display time alignment info for user reference
display_time_alignment_info() {
    local now="$1"

    print_info "TWAMM Time Alignment Reference (current time: $now):"
    echo "    Times within ~16s of now: align to multiples of 16"
    echo "    Times ~16s-256s away: align to multiples of 16"
    echo "    Times ~256s-4096s away: align to multiples of 256"
    echo "    Times ~4096s-65536s away: align to multiples of 4096"
    echo "    Times ~65536s+ away: align to multiples of 65536+"
    echo ""
    echo "    Tip: Use Unix timestamps that are multiples of 65536 (or larger powers of 16)"
    echo "         for distribution end times far in the future."
    echo ""

    # Show some example valid timestamps
    local example_step=65536
    local next_aligned=$(( (now / example_step + 1) * example_step ))
    echo "    Example valid end_times (multiples of $example_step):"
    for j in 1 2 3; do
        local ts=$((next_aligned + (j-1) * example_step * 10))
        echo "      $ts ($(date -d "@$ts" 2>/dev/null || date -r "$ts" 2>/dev/null || echo "use 'date -d @$ts' to view"))"
    done
    echo ""
}

# =============================================================================
# STRING ENCODING
# =============================================================================

# Encode short string (≤31 bytes) as ByteArray for sncast --calldata format
# ByteArray Serde: data_segments_len, pending_word, pending_word_len
# For strings ≤31 chars: 0 <hex_string> <length>
encode_short_string() {
    local str="$1"
    local len=${#str}

    if [ $len -eq 0 ]; then
        echo "0 0 0"
        return
    fi

    if [ $len -le 31 ]; then
        # Short string fits in pending_word
        local hex
        hex=$(printf '%s' "$str" | xxd -p | tr -d '\n')
        echo "0 0x$hex $len"
    else
        print_error "String too long (max 31 chars): $str"
        exit 1
    fi
}

# Build distribution orders for sncast --calldata format
# Returns: count buy_token fee start_time end_time amount recipient [...]
build_orders_calldata() {
    local config="$1"
    local count
    count=$(echo "$config" | jq '.distribution_orders | length')
    local calldata="$count"

    for i in $(seq 0 $((count - 1))); do
        local buy_token fee start_time end_time amount recipient amount_wei
        buy_token=$(echo "$config" | jq -r ".distribution_orders[$i].buy_token")
        fee=$(echo "$config" | jq -r ".distribution_orders[$i].fee")
        start_time=$(echo "$config" | jq -r ".distribution_orders[$i].start_time")
        end_time=$(echo "$config" | jq -r ".distribution_orders[$i].end_time")
        amount=$(echo "$config" | jq -r ".distribution_orders[$i].amount")
        recipient=$(echo "$config" | jq -r ".distribution_orders[$i].proceeds_recipient")

        # Convert to wei
        amount_wei=$(to_wei "$amount")

        calldata="$calldata $buy_token $fee $start_time $end_time $amount_wei $recipient"
    done

    echo "$calldata"
}

# Build premint allocations for sncast --calldata format
# Returns: count recipient amount [...]
build_premints_calldata() {
    local config="$1"
    local count
    count=$(echo "$config" | jq '.premint_allocations | length')
    local calldata="$count"

    for i in $(seq 0 $((count - 1))); do
        local recipient amount amount_wei
        recipient=$(echo "$config" | jq -r ".premint_allocations[$i].recipient")
        amount=$(echo "$config" | jq -r ".premint_allocations[$i].amount")

        # Convert to wei
        amount_wei=$(to_wei "$amount")

        calldata="$calldata $recipient $amount_wei"
    done

    echo "$calldata"
}

# Extract transaction hash from sncast output
extract_transaction_hash() {
    local output="$1"
    echo "$output" | grep -iE 'transaction.hash:?\s*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | head -1
}

# =============================================================================
# PARAMETER VALIDATION
# =============================================================================

check_dependencies

# Check for config file argument
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <config.json>"
    echo ""
    echo "Example:"
    echo "  export SNCAST_ACCOUNT=myaccount"
    echo "  export STREAM_TOKEN_FACTORY=0x..."
    echo "  $0 ./my_token_config.json"
    echo ""
    echo "See scripts/examples/token_config.example.json for configuration format."
    echo ""
    echo "NOTE: All token amounts are in human-readable format (18 decimals assumed)."
    echo "      Example: '1000000' = 1 million tokens"
    exit 1
fi

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

print_info "Validating parameters..."

missing_vars=()
[[ -z "${SNCAST_ACCOUNT:-}" ]] && missing_vars+=("SNCAST_ACCOUNT")
[[ -z "${STREAM_TOKEN_FACTORY:-}" ]] && missing_vars+=("STREAM_TOKEN_FACTORY")

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Usage:"
    echo "  export SNCAST_ACCOUNT=<your_sncast_account_name>"
    echo "  export STREAM_TOKEN_FACTORY=<factory_address>"
    echo "  $0 <config.json>"
    exit 1
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

STARKNET_RPC="${STARKNET_RPC:-$DEFAULT_RPC}"

# Validate factory address
validate_address "$STREAM_TOKEN_FACTORY" "STREAM_TOKEN_FACTORY"

# =============================================================================
# LOAD AND VALIDATE JSON CONFIG
# =============================================================================

print_step "Loading configuration from $CONFIG_FILE..."

CONFIG=$(cat "$CONFIG_FILE")

# Extract and validate required fields
TOKEN_NAME=$(echo "$CONFIG" | jq -r '.name')
TOKEN_SYMBOL=$(echo "$CONFIG" | jq -r '.symbol')
TOTAL_SUPPLY=$(echo "$CONFIG" | jq -r '.total_supply')

if [ "$TOKEN_NAME" == "null" ] || [ -z "$TOKEN_NAME" ]; then
    print_error "Missing required field: name"
    exit 1
fi

if [ "$TOKEN_SYMBOL" == "null" ] || [ -z "$TOKEN_SYMBOL" ]; then
    print_error "Missing required field: symbol"
    exit 1
fi

if [ "$TOTAL_SUPPLY" == "null" ] || [ -z "$TOTAL_SUPPLY" ]; then
    print_error "Missing required field: total_supply"
    exit 1
fi

# Extract liquidity config
PAIRED_TOKEN=$(echo "$CONFIG" | jq -r '.liquidity_config.paired_token')
POOL_FEE=$(echo "$CONFIG" | jq -r '.liquidity_config.fee')
STREAM_TOKEN_AMOUNT=$(echo "$CONFIG" | jq -r '.liquidity_config.stream_token_amount')
PAIRED_TOKEN_AMOUNT=$(echo "$CONFIG" | jq -r '.liquidity_config.paired_token_amount')

# Validate liquidity config
if [ "$PAIRED_TOKEN" == "null" ] || [ -z "$PAIRED_TOKEN" ]; then
    print_error "Missing required field: liquidity_config.paired_token"
    exit 1
fi
validate_address "$PAIRED_TOKEN" "liquidity_config.paired_token"

if [ "$STREAM_TOKEN_AMOUNT" == "null" ] || [ -z "$STREAM_TOKEN_AMOUNT" ]; then
    print_error "Missing required field: liquidity_config.stream_token_amount"
    exit 1
fi

if [ "$PAIRED_TOKEN_AMOUNT" == "null" ] || [ -z "$PAIRED_TOKEN_AMOUNT" ]; then
    print_error "Missing required field: liquidity_config.paired_token_amount"
    exit 1
fi

# Convert human-readable amounts to wei (18 decimals)
TOTAL_SUPPLY_WEI=$(to_wei "$TOTAL_SUPPLY")
STREAM_TOKEN_AMOUNT_WEI=$(to_wei "$STREAM_TOKEN_AMOUNT")
PAIRED_TOKEN_AMOUNT_WEI=$(to_wei "$PAIRED_TOKEN_AMOUNT")

# Min liquidity defaults to 0 (no slippage protection)
MIN_LIQUIDITY="${MIN_LIQUIDITY:-0}"

# Count arrays
ORDER_COUNT=$(echo "$CONFIG" | jq '.distribution_orders | length')
PREMINT_COUNT=$(echo "$CONFIG" | jq '.premint_allocations | length')

if [ "$ORDER_COUNT" -eq 0 ]; then
    print_error "At least one distribution order is required"
    exit 1
fi

if [ "$ORDER_COUNT" -gt 10 ]; then
    print_error "Maximum 10 distribution orders allowed (got $ORDER_COUNT)"
    exit 1
fi

# =============================================================================
# TWAMM TIME VALIDATION
# =============================================================================

print_step "Validating TWAMM time alignment..."

# Get current Unix timestamp
CURRENT_TIME=$(date +%s)

# Validate all order times
TIME_VALIDATION=$(validate_order_times "$CONFIG" "$CURRENT_TIME")

if [ "$TIME_VALIDATION" = "invalid" ]; then
    echo ""
    display_time_alignment_info "$CURRENT_TIME"
    print_error "Distribution order times are not TWAMM-aligned. Please fix the times above."
    exit 1
fi

print_info "All distribution order times are valid"

# =============================================================================
# DISPLAY CONFIGURATION
# =============================================================================

# Calculate implied price for display
PRICE_RATIO=$(awk -v s="$STREAM_TOKEN_AMOUNT" -v p="$PAIRED_TOKEN_AMOUNT" 'BEGIN { printf "%.10g", p / s }')

print_info "Token Configuration (all amounts in 18 decimals):"
cat << EOF

  Token Name:     $TOKEN_NAME
  Token Symbol:   $TOKEN_SYMBOL
  Total Supply:   $TOTAL_SUPPLY tokens ($TOTAL_SUPPLY_WEI wei)

  Liquidity Configuration:
    Paired Token:        $PAIRED_TOKEN
    Pool Fee:            $POOL_FEE
    Stream Token Amount: $STREAM_TOKEN_AMOUNT tokens
    Paired Token Amount: $PAIRED_TOKEN_AMOUNT tokens
    Implied Price:       1 $TOKEN_SYMBOL = $PRICE_RATIO paired tokens
    Min Liquidity:       $MIN_LIQUIDITY

  Distribution Orders: $ORDER_COUNT
EOF

for i in $(seq 0 $((ORDER_COUNT - 1))); do
    local_buy_token=$(echo "$CONFIG" | jq -r ".distribution_orders[$i].buy_token")
    local_fee=$(echo "$CONFIG" | jq -r ".distribution_orders[$i].fee")
    local_start=$(echo "$CONFIG" | jq -r ".distribution_orders[$i].start_time")
    local_end=$(echo "$CONFIG" | jq -r ".distribution_orders[$i].end_time")
    local_amount=$(echo "$CONFIG" | jq -r ".distribution_orders[$i].amount")
    local_recipient=$(echo "$CONFIG" | jq -r ".distribution_orders[$i].proceeds_recipient")
    echo "    Order $((i+1)):"
    echo "      Buy Token:  $local_buy_token"
    echo "      Fee:        $local_fee"
    echo "      Start:      $local_start"
    echo "      End:        $local_end"
    echo "      Amount:     $local_amount tokens"
    echo "      Recipient:  $local_recipient"
done

echo ""
echo "  Premint Allocations: $PREMINT_COUNT"

for i in $(seq 0 $((PREMINT_COUNT - 1))); do
    local_recipient=$(echo "$CONFIG" | jq -r ".premint_allocations[$i].recipient")
    local_amount=$(echo "$CONFIG" | jq -r ".premint_allocations[$i].amount")
    echo "    Allocation $((i+1)): $local_amount tokens to $local_recipient"
done

cat << EOF

  Factory:        $STREAM_TOKEN_FACTORY
  Account:        $SNCAST_ACCOUNT
  RPC:            $STARKNET_RPC

EOF

# Confirmation prompt
if [[ "${SKIP_CONFIRMATION:-false}" != "true" ]]; then
    read -p "Continue with token creation? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Token creation cancelled"
        exit 0
    fi
fi

# =============================================================================
# STEP 1: APPROVE FACTORY TO SPEND PAIRED TOKENS
# =============================================================================

print_step "Step 1: Approving factory to spend paired tokens..."

# u256 is passed as a single large number in sncast 0.55+
# Use --wait flag to automatically wait for transaction confirmation
APPROVE_OUTPUT=$(sncast --account "$SNCAST_ACCOUNT" \
    --wait --wait-timeout 120 \
    invoke \
    --url "$STARKNET_RPC" \
    --contract-address "$PAIRED_TOKEN" \
    --function "approve" \
    --arguments "$STREAM_TOKEN_FACTORY, $PAIRED_TOKEN_AMOUNT_WEI" 2>&1) || {
    print_error "Failed to approve paired tokens"
    print_error "Output: $APPROVE_OUTPUT"
    exit 1
}

print_verbose "$APPROVE_OUTPUT"

APPROVE_TX=$(extract_transaction_hash "$APPROVE_OUTPUT")
if [ -n "$APPROVE_TX" ]; then
    print_info "Approval transaction confirmed: $APPROVE_TX"
else
    print_warning "Could not extract approval transaction hash"
fi

# =============================================================================
# STEP 2: CREATE TOKEN
# =============================================================================

print_step "Step 2: Creating stream token..."

# Build the create_token calldata using raw felt serialization
# CreateTokenParams Serde order:
#   name: ByteArray (data_len, pending_word, pending_word_len)
#   symbol: ByteArray (data_len, pending_word, pending_word_len)
#   total_supply: u128
#   liquidity_config: LiquidityConfig
#     paired_token: ContractAddress
#     fee: u128
#     stream_token_amount: u128
#     paired_token_amount: u128
#     min_liquidity: u128
#   distribution_orders: Span<DistributionOrder>
#     len, [buy_token, fee, start_time, end_time, amount, recipient]...
#   premint_allocations: Span<PremintAllocation>
#     len, [recipient, amount]...

NAME_CALLDATA=$(encode_short_string "$TOKEN_NAME")
SYMBOL_CALLDATA=$(encode_short_string "$TOKEN_SYMBOL")
ORDERS_CALLDATA=$(build_orders_calldata "$CONFIG")
PREMINTS_CALLDATA=$(build_premints_calldata "$CONFIG")

# Full calldata as space-separated felts
CREATE_CALLDATA="$NAME_CALLDATA $SYMBOL_CALLDATA $TOTAL_SUPPLY_WEI $PAIRED_TOKEN $POOL_FEE $STREAM_TOKEN_AMOUNT_WEI $PAIRED_TOKEN_AMOUNT_WEI $MIN_LIQUIDITY $ORDERS_CALLDATA $PREMINTS_CALLDATA"

print_verbose "Create calldata: $CREATE_CALLDATA"

CREATE_OUTPUT=$(sncast --account "$SNCAST_ACCOUNT" \
    --wait --wait-timeout 120 \
    invoke \
    --url "$STARKNET_RPC" \
    --contract-address "$STREAM_TOKEN_FACTORY" \
    --function "create_token" \
    --calldata $CREATE_CALLDATA 2>&1) || {
    print_error "Failed to create token"
    print_error "Output: $CREATE_OUTPUT"
    exit 1
}

print_verbose "$CREATE_OUTPUT"

CREATE_TX=$(extract_transaction_hash "$CREATE_OUTPUT")
if [ -z "$CREATE_TX" ]; then
    print_error "Could not extract transaction hash from create_token output"
    print_error "Output: $CREATE_OUTPUT"
    exit 1
fi

print_info "Create token transaction: $CREATE_TX"

# =============================================================================
# STEP 3: EXTRACT TOKEN ADDRESS FROM TRANSACTION RECEIPT
# =============================================================================

print_step "Step 3: Extracting token address from transaction receipt..."

# Wait a moment for the transaction to be indexed
sleep 2

# Fetch transaction receipt and extract token address from StreamTokenCreated event
# The factory emits an event where keys[1] contains the token address
TOKEN_ADDRESS=""
FACTORY_ADDR_NORMALIZED=$(echo "$STREAM_TOKEN_FACTORY" | sed 's/^0x0*//')

RECEIPT_OUTPUT=$(curl -s -X POST "$STARKNET_RPC" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"starknet_getTransactionReceipt\",\"params\":[\"$CREATE_TX\"],\"id\":1}" 2>&1) || true

if [ -n "$RECEIPT_OUTPUT" ]; then
    # Find the event from the factory and extract token address from keys[1]
    TOKEN_ADDRESS=$(echo "$RECEIPT_OUTPUT" | jq -r --arg factory "$FACTORY_ADDR_NORMALIZED" \
        '.result.events[] | select(.from_address | contains($factory)) | .keys[1] // empty' 2>/dev/null | head -1) || true

    if [ -n "$TOKEN_ADDRESS" ] && [ "$TOKEN_ADDRESS" != "null" ]; then
        print_info "Token deployed at: $TOKEN_ADDRESS"
    else
        print_warning "Could not extract token address from receipt. Check Voyager for details."
    fi
fi

# =============================================================================
# SAVE DEPLOYMENT INFO
# =============================================================================

DEPLOYMENT_DIR="$REPO_ROOT/deployments"
DEPLOYMENT_FILE="$DEPLOYMENT_DIR/stream_token_$(date +%Y%m%d_%H%M%S).json"
mkdir -p "$DEPLOYMENT_DIR"

cat > "$DEPLOYMENT_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "rpc": "$STARKNET_RPC",
  "factory_address": "$STREAM_TOKEN_FACTORY",
  "config_file": "$CONFIG_FILE",
  "token": {
    "address": "${TOKEN_ADDRESS:-null}",
    "name": "$TOKEN_NAME",
    "symbol": "$TOKEN_SYMBOL",
    "total_supply": "$TOTAL_SUPPLY",
    "total_supply_wei": "$TOTAL_SUPPLY_WEI"
  },
  "transactions": {
    "approve_tx": "${APPROVE_TX:-null}",
    "create_token_tx": "$CREATE_TX"
  },
  "liquidity_config": {
    "paired_token": "$PAIRED_TOKEN",
    "fee": "$POOL_FEE",
    "stream_token_amount": "$STREAM_TOKEN_AMOUNT",
    "paired_token_amount": "$PAIRED_TOKEN_AMOUNT",
    "implied_price": "$PRICE_RATIO",
    "min_liquidity": "$MIN_LIQUIDITY"
  },
  "distribution_orders_count": $ORDER_COUNT,
  "premint_allocations_count": $PREMINT_COUNT
}
EOF

print_info "Deployment info saved to: $DEPLOYMENT_FILE"

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo -e "${GREEN}=== TOKEN CREATION COMPLETE ===${NC}"
echo ""
echo "Token Details:"
echo "  Name:           $TOKEN_NAME"
echo "  Symbol:         $TOKEN_SYMBOL"
echo "  Supply:         $TOTAL_SUPPLY tokens"
echo "  Implied Price:  1 $TOKEN_SYMBOL = $PRICE_RATIO paired tokens"
echo ""
if [ -n "$TOKEN_ADDRESS" ] && [ "$TOKEN_ADDRESS" != "null" ]; then
    echo "Deployed Token:"
    echo "  Address:       $TOKEN_ADDRESS"
    echo "  Voyager:       https://voyager.online/contract/$TOKEN_ADDRESS"
    echo ""
fi
echo "Transactions:"
echo "  Approve:       ${APPROVE_TX:-N/A}"
echo "  Create:        $CREATE_TX"
echo "  Voyager:       https://voyager.online/tx/$CREATE_TX"
echo ""
if [ -n "$TOKEN_ADDRESS" ] && [ "$TOKEN_ADDRESS" != "null" ]; then
    echo "Next Steps:"
    echo "  1. View token on Voyager: https://voyager.online/contract/$TOKEN_ADDRESS"
    echo "  2. Verify token is valid:"
    echo "     sncast call --url $STARKNET_RPC --contract-address $STREAM_TOKEN_FACTORY --function is_valid_token --calldata $TOKEN_ADDRESS"
else
    echo "Next Steps:"
    echo "  1. Check transaction on Voyager: https://voyager.online/tx/$CREATE_TX"
    echo "  2. Extract token address from StreamTokenCreated event"
    echo "  3. Verify token is valid:"
    echo "     sncast call --url $STARKNET_RPC --contract-address $STREAM_TOKEN_FACTORY --function is_valid_token --calldata <TOKEN_ADDRESS>"
fi
echo ""
