# Distribution

Distribution calculation library for computing share allocations across payout positions. Used for prize distribution, reward splitting, and any scenario requiring weighted payouts.

## Features

- Four distribution types: Linear, Exponential, Uniform, and Custom
- Configurable weight parameter for Linear and Exponential curves (scaled by 10, e.g., 15 = 1.5x)
- Dust handling to prevent stuck funds from rounding errors
- Shares expressed in basis points (10000 = 100%)
- Pure calculation functions (no storage or syscalls)
- StorePacking implementation for efficient on-chain storage

## Distribution Types

| Type | Description | Weight Parameter |
|------|-------------|-----------------|
| `Linear(weight)` | First place gets most, decreasing linearly | Higher weight = steeper curve |
| `Exponential(weight)` | Steep power-curve distribution | Higher weight = winner takes more |
| `Uniform` | Equal shares for all positions | N/A |
| `Custom(shares)` | User-defined shares per position | N/A (explicit shares) |

### Weight Examples (3 positions)

| Weight | Linear 1st | Linear 2nd | Linear 3rd |
|--------|-----------|-----------|-----------|
| 10 (1.0x) | ~50% | ~33% | ~17% |
| 20 (2.0x) | ~56% | ~33% | ~11% |
| 50 (5.0x) | ~61% | ~33% | ~6% |

## API Reference

```cairo
/// Calculate share for a payout position (basis points)
fn calculate_share(distribution, payout_index, total_payouts, available_share) -> u16

/// Calculate share with dust allocated to position 1 (winner)
fn calculate_share_with_dust(distribution, payout_index, total_payouts, available_share) -> u16

/// Sum of all payout shares
fn calculate_total(distribution, total_payouts, available_share) -> u16

/// Rounding remainder (available_share - sum of shares)
fn calculate_dust(distribution, total_payouts, available_share) -> u16
```

**Note:** `payout_index` is 1-indexed (1 = first place, 2 = second place, etc.)

## Usage

```cairo
use game_components_distribution::calculator::{calculate_share, calculate_share_with_dust};
use game_components_distribution::models::{Distribution, BASIS_POINTS};

// Linear distribution: 3 winners splitting 100%
let dist = Distribution::Linear(10); // weight 1.0
let first_place = calculate_share_with_dust(dist, 1, 3, BASIS_POINTS);  // ~5000 bp (50%)
let second_place = calculate_share_with_dust(dist, 2, 3, BASIS_POINTS); // ~3333 bp (33%)
let third_place = calculate_share_with_dust(dist, 3, 3, BASIS_POINTS);  // ~1667 bp (17%)
// Total guaranteed to equal BASIS_POINTS (dust goes to 1st place)

// Custom distribution
let dist = Distribution::Custom(array![5000_u16, 3000_u16, 2000_u16].span());
let first = calculate_share(dist, 1, 3, BASIS_POINTS);  // 5000 bp (50%)

// Partial available share (e.g., after deducting creator fee)
let dist = Distribution::Uniform;
let share = calculate_share(dist, 1, 4, 8000);  // 2000 bp (25% of 80%)
```

## Dependencies

- `game_components_math` - Fixed-point math for distribution calculations
- `game_components_interfaces` - `Distribution` enum definition
