#!/usr/bin/env bash
# Module catalog for CI test matrix generation.
# Sourced by both main-ci.yml and pr-ci.yml.
#
# All modules run on ubuntu-latest (standard 2-core runners).
# Partition counts are scaled to compensate: modules that previously
# needed 4-core runners get 4× partitions, 8-core get 8×.
#
# Usage:
#   source .github/workflows/module-catalog.sh
#   INCLUDES="[]"
#   add_all_modules          # or add selectively with add_egs, add_metagame, etc.
#   echo "$INCLUDES" | jq .

add() {
  INCLUDES=$(echo "$INCLUDES" | jq -c \
    --arg p "$1" --arg m "$2" \
    --argjson f "$3" --argjson total "$4" \
    '. + [range($total) | {package:$p, module:$m, runner:"ubuntu-latest", fuzzer_runs:$f, partition:(. + 1), total_partitions:$total}]')
}

# Embeddable Game Standard (previously 8-core or 4-core runners)
add_egs() {
  add game_components_embeddable_game_standard token     64  32   # was 8-core × 4 → 32 partitions
  add game_components_embeddable_game_standard minigame  64  8    # was 4-core × 2 → 8 partitions
  add game_components_embeddable_game_standard metagame  64  8    # was 4-core × 2 → 8 partitions
  add game_components_embeddable_game_standard registry  64  8    # was 4-core × 2 → 8 partitions
}

# Metagame extensions (previously 4-core runners)
add_metagame() {
  add game_components_metagame leaderboard        256 8
  add game_components_metagame registration       256 8
  add game_components_metagame entry_requirement  256 8
  add game_components_metagame entry_fee          256 8
  add game_components_metagame prize              256 8
  add game_components_metagame ticket_booth       256 8
}

# Economy (previously 4-core runner)
add_economy() {
  add game_components_economy tokenomics 256 8
}

# Utilities (previously 4-core runners)
add_utilities() {
  add game_components_utilities math         256 8
  add game_components_utilities distribution 256 4
  add game_components_utilities utils        256 8
  add game_components_utilities renderer     256 8
}

# Presets (previously 4-core runner)
add_presets() {
  add game_components_presets presets 256 8
}

# All modules — used by main-ci.yml (always runs everything)
add_all_modules() {
  add_egs
  add_metagame
  add_economy
  add_utilities
  add_presets
}
