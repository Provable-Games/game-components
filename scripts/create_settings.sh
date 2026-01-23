#!/bin/bash

# Death Mountain Settings Creator Script
# This script creates various game settings for the Death Mountain game

set -euo pipefail

# Load environment variables from .env file if it exists
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
YELLOW='\033[0;33m'
RED='\033[0;31m'
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

echo -e "${GREEN}====== Death Mountain Settings Creator ======${NC}"

# Check deployment environment
DEPLOY_TO_SLOT="${DEPLOY_TO_SLOT:-false}"

# Check if required environment variables are set
print_info "Checking environment variables..."

# Determine required vars based on deployment type
if [ "$DEPLOY_TO_SLOT" = "true" ]; then
    print_info "Deploying to Slot - reduced requirements"
    required_vars=("STARKNET_ACCOUNT" "STARKNET_RPC" "SETTINGS_CONTRACT")
else
    required_vars=("STARKNET_NETWORK" "STARKNET_ACCOUNT" "STARKNET_RPC" "STARKNET_PK" "SETTINGS_CONTRACT")
fi

missing_vars=()

# Debug output for environment variables
print_info "Environment variables loaded:"
echo "  DEPLOY_TO_SLOT: $DEPLOY_TO_SLOT"
echo "  STARKNET_NETWORK: ${STARKNET_NETWORK:-<not set>}"
echo "  STARKNET_ACCOUNT: ${STARKNET_ACCOUNT:-<not set>}"
echo "  STARKNET_RPC: ${STARKNET_RPC:-<not set>}"
echo "  STARKNET_PK: ${STARKNET_PK:+<set>}"
echo "  SETTINGS_CONTRACT: ${SETTINGS_CONTRACT:-<not set>}"

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

# Function to create a setting
create_setting() {
    local vrf_address=$1
    local name=$2
    local adventurer_health=$3
    local adventurer_xp=$4
    local adventurer_gold=$5
    local adventurer_beast_health=$6
    local adventurer_stat_upgrades=$7
    local stats_str=$8
    local stats_dex=$9
    local stats_vit=${10}
    local stats_int=${11}
    local stats_wis=${12}
    local stats_cha=${13}
    local stats_luck=${14}
    local weapon_id=${15}
    local weapon_xp=${16}
    local chest_id=${17}
    local chest_xp=${18}
    local head_id=${19}
    local head_xp=${20}
    local waist_id=${21}
    local waist_xp=${22}
    local foot_id=${23}
    local foot_xp=${24}
    local hand_id=${25}
    local hand_xp=${26}
    local neck_id=${27}
    local neck_xp=${28}
    local ring_id=${29}
    local ring_xp=${30}
    local item_specials_seed=${31}
    local action_count=${32}
    local bag_items=${33}
    local game_seed=${34}
    local game_seed_until_xp=${35}
    local in_battle=${36}
    local stats_mode=${37}
    local base_damage_reduction=${38}
    
    print_info "Creating setting: $name"
    
    # Build the invoke command
    local CMD="starkli invoke"
    CMD="$CMD --account $STARKNET_ACCOUNT"
    CMD="$CMD --rpc $STARKNET_RPC"
    
    if [ "$DEPLOY_TO_SLOT" != "true" ] && [ -n "$STARKNET_PK" ]; then
        CMD="$CMD --private-key $STARKNET_PK"
    fi
    
    CMD="$CMD --watch"
    CMD="$CMD $SETTINGS_CONTRACT"
    CMD="$CMD add_settings"
    
    # Add all parameters in order according to the function signature:
    # 1. vrf_address: ContractAddress
    CMD="$CMD $vrf_address"
    
    # 2. name: felt252
    CMD="$CMD $name"
    
    # 3. adventurer: Adventurer struct
    # The Adventurer struct contains these fields in order:
    # - health: u16
    # - xp: u16
    # - gold: u16
    # - beast_health: u16
    # - stat_upgrades_available: u8
    # - stats: Stats (7 fields)
    # - equipment: Equipment (8 Items, each with 2 fields)
    # - item_specials_seed: u16
    # - action_count: u16
    
    # Adventurer fields
    CMD="$CMD $adventurer_health $adventurer_xp $adventurer_gold $adventurer_beast_health $adventurer_stat_upgrades"
    # Stats sub-struct (7 fields)
    CMD="$CMD $stats_str $stats_dex $stats_vit $stats_int $stats_wis $stats_cha $stats_luck"
    # Equipment sub-struct (8 items, each with id and xp)
    CMD="$CMD $weapon_id $weapon_xp $chest_id $chest_xp $head_id $head_xp $waist_id $waist_xp $foot_id $foot_xp $hand_id $hand_xp $neck_id $neck_xp $ring_id $ring_xp"
    # Remaining adventurer fields
    CMD="$CMD $item_specials_seed $action_count"
    
    # 4. bag: Bag struct (15 items, each with id and xp = 30 values)
    local bag_items_spaced=$(echo "$bag_items" | tr ',' ' ')
    CMD="$CMD $bag_items_spaced"
    
    # 5. game_seed: u64
    CMD="$CMD $game_seed"
    
    # 6. game_seed_until_xp: u16
    CMD="$CMD $game_seed_until_xp"
    
    # 7. in_battle: bool
    CMD="$CMD $in_battle"
    
    # 8. stats_mode: StatsMode (enum)
    CMD="$CMD $stats_mode"
    
    # 9. base_damage_reduction: u8
    CMD="$CMD $base_damage_reduction"
    
    echo "Executing: $CMD"
    eval $CMD
    
    if [ $? -eq 0 ]; then
        print_info "Successfully created setting: $name"
    else
        print_error "Failed to create setting: $name"
        return 1
    fi
    echo "---"
}

# Default VRF address (you'll need to replace this with actual VRF address)
# Using a placeholder address - replace with your actual VRF contract address
VRF_ADDRESS="${VRF_ADDRESS:-0x0000000000000000000000000000000000000000000000000000000000000001}"

print_warning "Using VRF address: $VRF_ADDRESS"
print_warning "Update VRF_ADDRESS environment variable with your actual VRF contract address"
echo ""

# Confirm before proceeding
if [ "${SKIP_CONFIRMATION:-false}" != "true" ]; then
    read -p "Continue with creating settings? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Settings creation cancelled"
        exit 0
    fi
fi

# Example 1: Beginner Setting - Starting adventurer with basic equipment
echo -e "${GREEN}=== Example 1: Beginner Setting ===${NC}"
# Create bag items string (15 items, each with id,xp)
BAG_ITEMS_BEGINNER=""
for i in {1..15}; do
    if [ $i -gt 1 ]; then
        BAG_ITEMS_BEGINNER="$BAG_ITEMS_BEGINNER,"
    fi
    BAG_ITEMS_BEGINNER="${BAG_ITEMS_BEGINNER}0,0"  # Empty bag slots
done

create_setting \
    "$VRF_ADDRESS" \
    "0x426567696e6e6572" \
    100 \
    0 \
    25 \
    0 \
    0 \
    5 5 5 5 5 1 1 \
    5 0 \
    6 0 \
    7 0 \
    8 0 \
    9 0 \
    10 0 \
    11 0 \
    12 0 \
    12345 \
    0 \
    "$BAG_ITEMS_BEGINNER" \
    987654321 \
    100 \
    0 \
    1 \
    10

# Example 2: Veteran Setting - Mid-level adventurer
echo -e "${GREEN}=== Example 2: Veteran Setting ===${NC}"
# Create bag with some items
BAG_ITEMS_VETERAN="13,50,14,75,15,100"
for i in {4..15}; do
    BAG_ITEMS_VETERAN="$BAG_ITEMS_VETERAN,0,0"
done

create_setting \
    "$VRF_ADDRESS" \
    "0x56657465726e" \
    250 \
    5000 \
    500 \
    0 \
    5 \
    15 12 10 8 8 5 3 \
    20 500 \
    21 450 \
    22 400 \
    23 350 \
    24 300 \
    25 250 \
    26 200 \
    27 150 \
    54321 \
    250 \
    "$BAG_ITEMS_VETERAN" \
    111222333 \
    250 \
    0 \
    0 \
    15

# Example 3: Expert Setting - High-level adventurer
echo -e "${GREEN}=== Example 3: Expert Setting ===${NC}"
# Create full bag
BAG_ITEMS_EXPERT=""
for i in {1..15}; do
    if [ $i -gt 1 ]; then
        BAG_ITEMS_EXPERT="$BAG_ITEMS_EXPERT,"
    fi
    item_id=$((30 + i))
    item_xp=$((i * 100))
    BAG_ITEMS_EXPERT="${BAG_ITEMS_EXPERT}${item_id},${item_xp}"
done

create_setting \
    "$VRF_ADDRESS" \
    "0x457870657274" \
    500 \
    25000 \
    2500 \
    0 \
    10 \
    25 20 18 15 15 10 8 \
    50 2000 \
    51 1900 \
    52 1800 \
    53 1700 \
    54 1600 \
    55 1500 \
    56 1400 \
    57 1300 \
    99999 \
    1000 \
    "$BAG_ITEMS_EXPERT" \
    555666777 \
    500 \
    0 \
    1 \
    25

# Example 4: Battle Mode Setting - Adventurer in combat
echo -e "${GREEN}=== Example 4: Battle Mode Setting ===${NC}"
BAG_ITEMS_BATTLE="60,100,61,200"
for i in {3..15}; do
    BAG_ITEMS_BATTLE="$BAG_ITEMS_BATTLE,0,0"
done

create_setting \
    "$VRF_ADDRESS" \
    "0x426174746c65" \
    180 \
    3000 \
    300 \
    75 \
    2 \
    12 15 8 10 6 4 5 \
    30 750 \
    31 700 \
    32 650 \
    33 600 \
    34 550 \
    35 500 \
    36 450 \
    37 400 \
    77777 \
    150 \
    "$BAG_ITEMS_BATTLE" \
    999888777 \
    200 \
    1 \
    0 \
    20

# Example 5: Speedrun Setting - Minimal gear, high stats
echo -e "${GREEN}=== Example 5: Speedrun Setting ===${NC}"
BAG_ITEMS_SPEED="0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"

create_setting \
    "$VRF_ADDRESS" \
    "0x537065656472756e" \
    50 \
    0 \
    0 \
    0 \
    20 \
    30 30 5 5 5 15 20 \
    1 0 \
    0 0 \
    0 0 \
    0 0 \
    0 0 \
    0 0 \
    0 0 \
    0 0 \
    11111 \
    0 \
    "$BAG_ITEMS_SPEED" \
    123123123 \
    50 \
    0 \
    0 \
    5

echo -e "${GREEN}====== Settings Creation Complete ======${NC}"
echo ""
print_info "Usage Notes:"
echo "1. Set VRF_ADDRESS environment variable with your actual VRF contract address"
echo "2. Set SETTINGS_CONTRACT environment variable with your settings contract address"
echo "3. Run with different profiles: DEPLOY_TO_SLOT=true ./create_settings.sh"
echo "4. Customize the examples or create new settings by calling create_setting function"
echo ""
print_info "Setting Parameters:"
echo "- name: Setting name (as felt252 hex string)"
echo "- adventurer: Health, XP, Gold, Beast Health, Stat Upgrades Available"
echo "- stats: STR, DEX, VIT, INT, WIS, CHA, LUCK (max 31 each)"
echo "- equipment: 8 items (weapon, chest, head, waist, foot, hand, neck, ring)"
echo "- bag: 15 item slots (each with id and xp)"
echo "- game settings: seed, seed_until_xp, in_battle (0/1), stats_mode (0=Dodge/1=Reduction), base_damage_reduction"