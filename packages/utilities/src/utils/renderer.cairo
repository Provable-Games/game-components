use alexandria_encoding::base64::Base64Encoder;
use core::array::SpanTrait;
use core::clone::Clone;
use core::num::traits::Zero;
use core::traits::Into;
use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use game_components_embeddable_game_standard::minigame::extensions::objectives::structs::GameObjectiveDetails;
use game_components_embeddable_game_standard::minigame::extensions::settings::structs::GameSettingDetails;
use game_components_embeddable_game_standard::minigame::structs::GameDetail;
use game_components_embeddable_game_standard::registry::interface::GameMetadata;
use game_components_embeddable_game_standard::token::structs::TokenMetadata;
use graffiti::json::JsonImpl;
use starknet::{ContractAddress, get_block_timestamp};
use crate::utils::encoding::{U256BytesUsedTraitImpl, bytes_base64_encode};

fn create_text(
    text: ByteArray,
    x: ByteArray,
    y: ByteArray,
    fontsize: ByteArray,
    baseline: ByteArray,
    text_anchor: ByteArray,
) -> ByteArray {
    "<text x='"
        + x
        + "' y='"
        + y
        + "' font-size='"
        + fontsize
        + "' text-anchor='"
        + text_anchor
        + "' dominant-baseline='"
        + baseline
        + "'>"
        + text
        + "</text>"
}

fn create_trait(name: ByteArray, value: ByteArray) -> ByteArray {
    JsonImpl::new().add("trait", name).add("value", value).build()
}

fn bool_to_str(val: bool) -> ByteArray {
    if val {
        "True"
    } else {
        "False"
    }
}

/// Converts a unix timestamp to a "YYYY-MM-DD HH:MM" datetime string.
/// Uses the Howard Hinnant civil_from_days algorithm.
/// Returns "---" for timestamp 0.
fn timestamp_to_datetime(timestamp: u64) -> ByteArray {
    if timestamp == 0 {
        return "---";
    }
    let days_since_epoch: u64 = timestamp / 86400;
    let z: u64 = days_since_epoch + 719468;
    let era: u64 = z / 146097;
    let doe: u64 = z - era * 146097;
    let yoe: u64 = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y: u64 = yoe + era * 400;
    let doy: u64 = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp: u64 = (5 * doy + 2) / 153;
    let d: u64 = doy - (153 * mp + 2) / 5 + 1;
    let m: u64 = if mp < 10 {
        mp + 3
    } else {
        mp - 9
    };
    let y: u64 = if m <= 2 {
        y + 1
    } else {
        y
    };
    let mm: ByteArray = if m < 10 {
        format!("0{}", m)
    } else {
        format!("{}", m)
    };
    let dd: ByteArray = if d < 10 {
        format!("0{}", d)
    } else {
        format!("{}", d)
    };
    let remaining = timestamp % 86400;
    let hours = remaining / 3600;
    let minutes = (remaining % 3600) / 60;
    let hh: ByteArray = if hours < 10 {
        format!("0{}", hours)
    } else {
        format!("{}", hours)
    };
    let mi: ByteArray = if minutes < 10 {
        format!("0{}", minutes)
    } else {
        format!("{}", minutes)
    };
    format!("{}", y) + "-" + mm + "-" + dd + " " + hh + ":" + mi
}

/// Calculate timeline progress as a percentage (0-100).
/// Returns 0 if start >= end or current <= start, 100 if current >= end.
fn calculate_timeline_progress(start: u64, end: u64, current: u64) -> u64 {
    if start >= end || current <= start {
        return 0;
    }
    if current >= end {
        return 100;
    }
    (current - start) * 100 / (end - start)
}

pub fn create_default_svg(
    game_metadata: GameMetadata,
    token_metadata: TokenMetadata,
    score: u64,
    player_name: felt252,
    settings_details: GameSettingDetails,
    objective_details: GameObjectiveDetails,
    context_details: GameContextDetails,
) -> ByteArray {
    let accent = if game_metadata.color.len() == 0 {
        "#ffffff"
    } else {
        game_metadata.color.clone()
    };
    let _game_id = format!("{}", token_metadata.game_id);
    let _score = format!("{}", score);
    let _game_name = format!("{}", game_metadata.name);
    let _developer = format!("{}", game_metadata.developer);
    let _genre = format!("{}", game_metadata.genre);
    let desc_raw = game_metadata.description;
    let _settings_name: ByteArray = if settings_details.name.len() > 0 {
        settings_details.name
    } else {
        "---"
    };
    let _objective_name: ByteArray = if objective_details.name.len() > 0 {
        objective_details.name
    } else {
        "---"
    };
    let _minted_at = timestamp_to_datetime(token_metadata.minted_at);
    let _start = timestamp_to_datetime(token_metadata.lifecycle.start);
    let _end = timestamp_to_datetime(token_metadata.lifecycle.end);

    let mut _player_name: ByteArray = Default::default();
    if player_name.is_non_zero() {
        _player_name
            .append_word(
                player_name, U256BytesUsedTraitImpl::bytes_used(player_name.into()).into(),
            );
    } else {
        _player_name = "---";
    }

    // Timeline progress
    let current_ts = get_block_timestamp();
    let progress = calculate_timeline_progress(
        token_metadata.lifecycle.start, token_metadata.lifecycle.end, current_ts,
    );
    let track_width: u64 = 396;
    let fill_width: u64 = track_width * progress / 100;
    let marker_x: u64 = 37 + fill_width;

    // Context details
    let _context_name: ByteArray = if context_details.name.len() > 0 {
        context_details.name.clone()
    } else {
        "---"
    };

    // Royalty percentage from basis points
    let royalty_bps: u128 = game_metadata.royalty_fraction;
    let royalty_whole: u128 = royalty_bps / 100;
    let royalty_frac: u128 = royalty_bps % 100;
    let _royalty: ByteArray = if royalty_frac == 0 {
        format!("{}%", royalty_whole)
    } else if royalty_frac % 10 == 0 {
        format!("{}.{}%", royalty_whole, royalty_frac / 10)
    } else if royalty_frac < 10 {
        format!("{}.0{}%", royalty_whole, royalty_frac)
    } else {
        format!("{}.{}%", royalty_whole, royalty_frac)
    };

    let mut svg: ByteArray = "";

    // SVG open
    svg
        .append(
            @"<svg xmlns='http://www.w3.org/2000/svg' width='530' height='620' viewBox='-30 -10 530 620'>",
        );

    // Defs: gradients, patterns, filters, icons
    svg.append(@"<defs>");
    svg.append(@"<linearGradient id='panel' x1='0%' y1='0%' x2='0%' y2='100%'>");
    svg.append(@"<stop offset='0%' stop-color='#2d2d32'/>");
    svg.append(@"<stop offset='100%' stop-color='#1e1e22'/>");
    svg.append(@"</linearGradient>");
    svg
        .append(
            @"<linearGradient id='accentGrad' gradientUnits='userSpaceOnUse' x1='0' y1='0' x2='470' y2='0'>",
        );
    svg.append(@"<stop offset='0%' stop-color='");
    svg.append(@accent);
    svg.append(@"' stop-opacity='0.6'/><stop offset='50%' stop-color='");
    svg.append(@accent);
    svg.append(@"'/><stop offset='100%' stop-color='");
    svg.append(@accent);
    svg.append(@"' stop-opacity='0.6'/>");
    svg
        .append(
            @"<animateTransform attributeName='gradientTransform' type='rotate' from='0 235 300' to='360 235 300' dur='6s' repeatCount='indefinite'/>",
        );
    svg.append(@"</linearGradient>");
    svg
        .append(
            @"<pattern id='pin' width='12' height='12' patternUnits='userSpaceOnUse' patternTransform='rotate(12)'>",
        );
    svg.append(@"<path fill='#1b1b1f' d='M0 0h12v12H0z'/>");
    svg.append(@"<path fill='#242428' opacity='.3' d='M0 0h12v6H0z'/>");
    svg.append(@"</pattern>");
    // Glow filter
    svg.append(@"<filter id='glow'><feGaussianBlur stdDeviation='3' result='blur'/>");
    svg.append(@"<feMerge><feMergeNode in='blur'/><feMergeNode in='SourceGraphic'/></feMerge>");
    svg.append(@"</filter>");
    // Scanline pattern
    svg.append(@"<pattern id='scan' width='470' height='4' patternUnits='userSpaceOnUse'>");
    svg.append(@"<rect width='470' height='2' fill='#000' opacity='0.06'/>");
    svg.append(@"</pattern>");
    // Shimmer gradient
    svg.append(@"<linearGradient id='shimmer' x1='0' y1='0' x2='1' y2='1'>");
    svg
        .append(
            @"<stop offset='0%' stop-color='#fff' stop-opacity='0'/><stop offset='45%' stop-color='#fff' stop-opacity='0'/>",
        );
    svg
        .append(
            @"<stop offset='50%' stop-color='#fff' stop-opacity='0.08'/><stop offset='55%' stop-color='#fff' stop-opacity='0'/>",
        );
    svg.append(@"<stop offset='100%' stop-color='#fff' stop-opacity='0'/>");
    svg
        .append(
            @"<animateTransform attributeName='gradientTransform' type='translate' from='-1 -1' to='1 1' dur='3s' repeatCount='indefinite'/>",
        );
    svg.append(@"</linearGradient>");
    // Vignette
    svg.append(@"<radialGradient id='vignette' cx='50%' cy='50%' r='70%'>");
    svg.append(@"<stop offset='0%' stop-color='#000' stop-opacity='0'/>");
    svg.append(@"<stop offset='100%' stop-color='#000' stop-opacity='0.3'/>");
    svg.append(@"</radialGradient>");

    // Icon symbols (16x16 viewBox)
    // Star icon (score)
    svg
        .append(
            @"<symbol id='ico-star' viewBox='0 0 16 16'><path fill='currentColor' d='M8 1l2.2 4.5 5 .7-3.6 3.5.8 5L8 12.4 3.6 14.7l.8-5L.8 6.2l5-.7z'/></symbol>",
        );
    // User icon (player)
    svg
        .append(
            @"<symbol id='ico-user' viewBox='0 0 16 16'><circle fill='currentColor' cx='8' cy='5' r='3'/><path fill='currentColor' d='M2 14c0-3.3 2.7-6 6-6s6 2.7 6 6z'/></symbol>",
        );
    // Check icon (objective complete)
    svg
        .append(
            @"<symbol id='ico-check' viewBox='0 0 16 16'><path fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' d='M3 8l3.5 3.5L13 5'/></symbol>",
        );
    // X-mark icon (game over)
    svg
        .append(
            @"<symbol id='ico-x' viewBox='0 0 16 16'><path fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' d='M4 4l8 8M12 4l-8 8'/></symbol>",
        );
    // Lock icon (soulbound)
    svg
        .append(
            @"<symbol id='ico-lock' viewBox='0 0 16 16'><rect fill='currentColor' x='3' y='7' width='10' height='7' rx='1'/><path fill='none' stroke='currentColor' stroke-width='1.5' d='M5 7V5a3 3 0 016 0v2'/></symbol>",
        );
    // Clock icon (timeline)
    svg
        .append(
            @"<symbol id='ico-clock' viewBox='0 0 16 16'><circle fill='none' stroke='currentColor' stroke-width='1.5' cx='8' cy='8' r='6'/><path fill='none' stroke='currentColor' stroke-width='1.5' stroke-linecap='round' d='M8 4v4l2.5 2.5'/></symbol>",
        );
    // Gear icon (settings)
    svg
        .append(
            @"<symbol id='ico-gear' viewBox='0 0 16 16'><path fill='currentColor' d='M6.8 1h2.4l.4 2 .7.3 1.7-1.1 1.7 1.7-1.1 1.7.3.7 2 .4v2.4l-2 .4-.3.7 1.1 1.7-1.7 1.7-1.7-1.1-.7.3-.4 2H6.8l-.4-2-.7-.3-1.7 1.1-1.7-1.7 1.1-1.7-.3-.7-2-.4V6.8l2-.4.3-.7L3.2 4l1.7-1.7 1.7 1.1.7-.3z'/><circle fill='#1e1e22' cx='8' cy='8' r='2.5'/></symbol>",
        );
    // Target icon (objective)
    svg
        .append(
            @"<symbol id='ico-target' viewBox='0 0 16 16'><circle fill='none' stroke='currentColor' stroke-width='1.5' cx='8' cy='8' r='6'/><circle fill='none' stroke='currentColor' stroke-width='1.5' cx='8' cy='8' r='3'/><circle fill='currentColor' cx='8' cy='8' r='1.5'/></symbol>",
        );
    // Flag icon (timeline start/end)
    svg
        .append(
            @"<symbol id='ico-flag' viewBox='0 0 16 16'><path fill='none' stroke='currentColor' stroke-width='1.5' stroke-linecap='round' d='M4 14V2'/><path fill='currentColor' d='M4 2l8 3-8 3z'/></symbol>",
        );

    // Styles with card tilt animation and split left/right edge thickness
    svg
        .append(
            @"<style>.l{fill:#c9c9d1;font-size:13px;letter-spacing:0.5px}.v{fill:#fff;font-size:16px}.vs{fill:#fff;font-size:13px}text{font-family:'Courier New',Courier,monospace;text-transform:uppercase}@keyframes tilt{0%,100%{transform:perspective(800px) rotateY(-8deg)}50%{transform:perspective(800px) rotateY(8deg)}}@keyframes sl{0%,100%{opacity:1}20%{opacity:0.15}25%,75%{opacity:0}80%{opacity:0.15}}@keyframes sr{0%,25%,75%,100%{opacity:0}30%{opacity:0.15}50%{opacity:1}70%{opacity:0.15}}.card{animation:tilt 6s ease-in-out infinite;transform-origin:235px 300px}.el-o{fill:#1a1a1e;animation:sl 6s ease-in-out infinite}.el-i{fill:#2a2a30;animation:sl 6s ease-in-out infinite}.er-o{fill:#1a1a1e;animation:sr 6s ease-in-out infinite}.er-i{fill:#2a2a30;animation:sr 6s ease-in-out infinite}</style>",
        );
    svg.append(@"</defs>");

    // Card group with tilt animation and 3D depth
    svg.append(@"<g class='card'>");

    // Left edge paths (visible when card tilts left, opacity animated via sl)
    svg.append(@"<path class='el-o' d='M-8 16 Q-8 0 16 0 L16 600 Q-8 600 -8 584 Z'/>");
    svg.append(@"<path class='el-i' d='M-4 16 Q-4 0 16 0 L16 600 Q-4 600 -4 584 Z'/>");
    // Right edge paths (visible when card tilts right, opacity animated via sr)
    svg.append(@"<path class='er-o' d='M478 16 Q478 0 454 0 L454 600 Q478 600 478 584 Z'/>");
    svg.append(@"<path class='er-i' d='M474 16 Q474 0 454 0 L454 600 Q474 600 474 584 Z'/>");

    // Background layers
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#pin)'/>");
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#vignette)'/>");
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#scan)'/>");
    // Animated gradient border with glow
    svg
        .append(
            @"<rect x='3' y='3' width='464' height='594' rx='15' fill='none' stroke='url(#accentGrad)' stroke-width='6' filter='url(#glow)'/>",
        );
    // Shimmer sweep
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#shimmer)'/>");

    // ── Header: EGS logo placeholder + game name + game ID ──
    svg.append(@"<rect x='18' y='24' width='44' height='44' rx='8' fill='url(#panel)' stroke='");
    svg.append(@accent);
    svg.append(@"' stroke-width='1.5'/>");
    svg
        .append(
            @"<text x='40' y='51' text-anchor='middle' style='fill:#c9c9d1;font-size:11px'>EGS</text>",
        );

    // Game name
    svg.append(@"<text x='72' y='38' style='fill:#fff;font-size:22px;letter-spacing:1px'>");
    svg += _game_name;
    svg.append(@"</text>");
    // Developer + Genre
    svg.append(@"<text x='72' y='56' class='l'>");
    svg += _developer;
    svg.append(@"</text>");
    svg.append(@"<text x='72' y='70' class='l' style='font-size:11px'>");
    svg += _genre;
    svg.append(@"</text>");

    // Game ID badge (top right)
    svg.append(@"<text x='440' y='38' text-anchor='end' style='fill:");
    svg.append(@accent);
    svg.append(@";font-size:20px'>GAME #");
    svg += _game_id;
    svg.append(@"</text>");

    // Accent separator
    svg.append(@"<line x1='25' y1='80' x2='445' y2='80' stroke='");
    svg.append(@accent);
    svg.append(@"' stroke-width='1' opacity='0.5'/>");

    // ── Game image area (centered square) ──
    svg
        .append(
            @"<rect x='175' y='88' width='120' height='120' rx='10' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<image x='180' y='93' width='110' height='110' href='");
    svg += game_metadata.image;
    svg.append(@"' preserveAspectRatio='xMidYMid meet'/>");

    // ── Status Badge Panels flanking game image (2 left, 2 right) ──
    // Badge 1: STATUS (top-left, y:88-144)
    svg
        .append(
            @"<rect x='25' y='88' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.game_over {
        svg.append(@"<rect x='25' y='88' width='4' height='56' rx='2' fill='#ef4444'/>");
        svg
            .append(
                @"<use href='#ico-x' x='39' y='102' width='14' height='14' style='color:#ef4444'/>",
            );
        svg
            .append(
                @"<text x='58' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>STATUS</text>",
            );
        svg.append(@"<text x='39' y='132' style='fill:#fff;font-size:13px'>FINISHED</text>");
    } else {
        svg.append(@"<rect x='25' y='88' width='4' height='56' rx='2' fill='#10b981'/>");
        svg
            .append(
                @"<use href='#ico-check' x='39' y='102' width='14' height='14' style='color:#10b981'/>",
            );
        svg
            .append(
                @"<text x='58' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>STATUS</text>",
            );
        svg.append(@"<text x='39' y='132' style='fill:#fff;font-size:13px'>ACTIVE</text>");
    }

    // Badge 2: BINDING (bottom-left, y:152-208)
    svg
        .append(
            @"<rect x='25' y='152' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.soulbound {
        svg.append(@"<rect x='25' y='152' width='4' height='56' rx='2' fill='");
        svg.append(@accent);
        svg.append(@"'/>");
        svg.append(@"<use href='#ico-lock' x='39' y='166' width='14' height='14' style='color:");
        svg.append(@accent);
        svg.append(@"'/>");
        svg
            .append(
                @"<text x='58' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>BINDING</text>",
            );
        svg.append(@"<text x='39' y='196' style='fill:#fff;font-size:13px'>SOULBOUND</text>");
    } else {
        svg.append(@"<rect x='25' y='152' width='4' height='56' rx='2' fill='#555'/>");
        svg
            .append(
                @"<use href='#ico-lock' x='39' y='166' width='14' height='14' style='color:#555'/>",
            );
        svg
            .append(
                @"<text x='58' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>BINDING</text>",
            );
        svg.append(@"<text x='39' y='196' style='fill:#888;font-size:13px'>TRANSFERABLE</text>");
    }

    // Badge 3: PAYMASTER (top-right, y:88-144)
    svg
        .append(
            @"<rect x='303' y='88' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.paymaster {
        svg.append(@"<rect x='303' y='88' width='4' height='56' rx='2' fill='#10b981'/>");
        svg
            .append(
                @"<use href='#ico-check' x='317' y='102' width='14' height='14' style='color:#10b981'/>",
            );
        svg
            .append(
                @"<text x='336' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>PAYMASTER</text>",
            );
        svg.append(@"<text x='317' y='132' style='fill:#fff;font-size:13px'>SPONSORED</text>");
    } else {
        svg.append(@"<rect x='303' y='88' width='4' height='56' rx='2' fill='#555'/>");
        svg
            .append(
                @"<use href='#ico-x' x='317' y='102' width='14' height='14' style='color:#555'/>",
            );
        svg
            .append(
                @"<text x='336' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>PAYMASTER</text>",
            );
        svg.append(@"<text x='317' y='132' style='fill:#888;font-size:13px'>STANDARD</text>");
    }

    // Badge 4: OBJECTIVE (bottom-right, y:152-208)
    svg
        .append(
            @"<rect x='303' y='152' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.completed_objective {
        svg.append(@"<rect x='303' y='152' width='4' height='56' rx='2' fill='");
        svg.append(@accent);
        svg.append(@"'/>");
        svg.append(@"<use href='#ico-check' x='317' y='166' width='14' height='14' style='color:");
        svg.append(@accent);
        svg.append(@"'/>");
        svg
            .append(
                @"<text x='336' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OBJECTIVE</text>",
            );
        svg.append(@"<text x='317' y='196' style='fill:#fff;font-size:13px'>COMPLETE</text>");
    } else {
        svg.append(@"<rect x='303' y='152' width='4' height='56' rx='2' fill='#555'/>");
        svg
            .append(
                @"<use href='#ico-x' x='317' y='166' width='14' height='14' style='color:#555'/>",
            );
        svg
            .append(
                @"<text x='336' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OBJECTIVE</text>",
            );
        svg.append(@"<text x='317' y='196' style='fill:#888;font-size:13px'>PENDING</text>");
    }

    // ── Game Description (y:220-248, up to 3 word-wrapped lines) ──
    let desc_len = desc_raw.len();
    if desc_len > 0 {
        let max_per_line: u32 = 55;
        let max_lines: u32 = 3;
        let mut pos: u32 = 0;
        let mut line_num: u32 = 0;
        loop {
            if pos >= desc_len || line_num >= max_lines {
                break;
            }
            let remaining = desc_len - pos;
            let is_last_line = line_num == max_lines - 1;
            let line_end = if remaining <= max_per_line {
                desc_len
            } else {
                let limit = if is_last_line {
                    pos + max_per_line - 3
                } else {
                    pos + max_per_line
                };
                // Search backwards for a space to break at
                let mut bp = limit;
                loop {
                    if bp <= pos {
                        break limit; // no space found, hard break
                    }
                    if desc_raw.at(bp).unwrap() == 0x20 {
                        break bp;
                    }
                    bp -= 1;
                }
            };
            let y_pos: u32 = 220 + line_num * 14;
            svg.append(@"<text x='235' y='");
            svg += format!("{}", y_pos);
            svg.append(@"' text-anchor='middle' style='fill:#888;font-size:10px'>");
            let mut ci = pos;
            loop {
                if ci >= line_end {
                    break;
                }
                svg.append_byte(desc_raw.at(ci).unwrap());
                ci += 1;
            }
            if is_last_line && desc_len > line_end {
                svg.append(@"...");
            }
            svg.append(@"</text>");
            pos =
                if line_end < desc_len {
                    if desc_raw.at(line_end).unwrap() == 0x20 {
                        line_end + 1
                    } else {
                        line_end
                    }
                } else {
                    line_end
                };
            line_num += 1;
        };
    }

    // ── Two-Col Panels Row 1 (y:264-314): PLAYER | SCORE ──
    // Player panel with accent left-border
    svg
        .append(
            @"<rect x='25' y='264' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='264' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<use href='#ico-user' x='37' y='273' width='14' height='14' style='color:#c9c9d1'/>",
        );
    svg.append(@"<text x='56' y='285' class='l'>PLAYER</text>");
    svg.append(@"<text x='37' y='304' class='vs'>");
    svg += _player_name;
    svg.append(@"</text>");

    // Score panel with accent left-border
    svg
        .append(
            @"<rect x='240' y='264' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='240' y='264' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<use href='#ico-star' x='252' y='273' width='14' height='14' style='color:#c9c9d1'/>",
        );
    svg.append(@"<text x='271' y='285' class='l'>SCORE</text>");
    svg.append(@"<text x='252' y='304' class='v'>");
    svg += _score;
    svg.append(@"</text>");

    // ── Two-Col Panels Row 2 (y:322-372): SETTINGS | OBJECTIVE ──
    // Settings panel with gear icon
    svg
        .append(
            @"<rect x='25' y='322' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='322' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<use href='#ico-gear' x='37' y='331' width='14' height='14' style='color:#c9c9d1'/>",
        );
    svg.append(@"<text x='56' y='343' class='l'>SETTINGS</text>");
    svg.append(@"<text x='37' y='362' class='vs'>");
    svg += _settings_name;
    svg.append(@"</text>");

    // Objective panel with target icon
    svg
        .append(
            @"<rect x='240' y='322' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='240' y='322' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<use href='#ico-target' x='252' y='331' width='14' height='14' style='color:#c9c9d1'/>",
        );
    svg.append(@"<text x='271' y='343' class='l'>OBJECTIVE</text>");
    svg.append(@"<text x='252' y='362' class='vs'>");
    svg += _objective_name;
    svg.append(@"</text>");

    // ── Timeline Bordered Section (y:380-438) ──
    svg
        .append(
            @"<rect x='25' y='380' width='420' height='58' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='380' width='4' height='58' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<use href='#ico-clock' x='37' y='388' width='14' height='14' style='color:#c9c9d1'/>",
        );
    svg.append(@"<text x='56' y='400' class='l'>TIMELINE</text>");
    // Start flag + datetime
    svg
        .append(
            @"<use href='#ico-flag' x='37' y='406' width='12' height='12' style='color:#10b981'/>",
        );
    svg.append(@"<text x='52' y='416' style='fill:#888;font-size:10px'>");
    svg += _start;
    svg.append(@"</text>");
    // End flag + datetime (right-aligned)
    svg.append(@"<text x='419' y='416' text-anchor='end' style='fill:#888;font-size:10px'>");
    svg += _end;
    svg.append(@"</text>");
    svg
        .append(
            @"<use href='#ico-flag' x='421' y='406' width='12' height='12' style='color:#ef4444'/>",
        );
    // Track background
    svg.append(@"<rect x='37' y='426' width='396' height='6' rx='3' fill='#3a3a40'/>");
    // Filled portion
    svg.append(@"<rect x='37' y='426' width='");
    svg += format!("{}", fill_width);
    svg.append(@"' height='6' rx='3' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    // Marker circle
    svg.append(@"<circle cx='");
    svg += format!("{}", marker_x);
    svg.append(@"' cy='429' r='5' fill='");
    svg.append(@accent);
    svg.append(@"' stroke='#fff' stroke-width='1.5'/>");

    // ── Context Bordered Section (y:446-514) ──
    svg
        .append(
            @"<rect x='25' y='446' width='420' height='68' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='446' width='4' height='68' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg.append(@"<text x='37' y='464' class='l'>CONTEXT</text>");
    svg.append(@"<text x='112' y='464' class='vs'>");
    svg += _context_name;
    svg.append(@"</text>");

    // Up to 3 context key:value pairs
    let ctx_span = context_details.context;
    let ctx_len = ctx_span.len();
    if ctx_len > 0 {
        let max_entries: u32 = if ctx_len < 3 {
            ctx_len
        } else {
            3
        };
        let mut ctx_i: u32 = 0;
        let y_base: u32 = 479;
        loop {
            if ctx_i >= max_entries {
                break;
            }
            let entry = ctx_span.at(ctx_i);
            let y_pos = y_base + ctx_i * 15;
            svg.append(@"<text x='37' y='");
            svg += format!("{}", y_pos);
            svg.append(@"' style='fill:#888;font-size:10px'>");
            svg += entry.name.clone();
            svg.append(@": ");
            svg += entry.value.clone();
            svg.append(@"</text>");
            ctx_i += 1;
        };
    }

    // ── Footer ──
    svg.append(@"<line x1='25' y1='522' x2='445' y2='522' stroke='");
    svg.append(@accent);
    svg.append(@"' stroke-width='1' opacity='0.3'/>");
    // Royalty (left) + Minted (right)
    svg
        .append(
            @"<text x='25' y='538' style='fill:#888;font-size:10px;letter-spacing:1px'>ROYALTY: ",
        );
    svg += _royalty;
    svg.append(@"</text>");
    svg.append(@"<text x='445' y='538' text-anchor='end' style='fill:#555;font-size:9px'>MINTED ");
    svg += _minted_at;
    svg.append(@"</text>");
    // EGS footer
    svg
        .append(
            @"<text x='235' y='556' text-anchor='middle' class='l' style='font-size:13px;letter-spacing:2px'>EMBEDDABLE GAME STANDARD</text>",
        );

    svg.append(@"</g>"); // close card group
    svg.append(@"</svg>");

    format!("data:image/svg+xml;base64,{}", bytes_base64_encode(svg))
}

pub fn create_custom_metadata(
    token_id: felt252,
    token_name: ByteArray,
    token_description: ByteArray,
    game_metadata: GameMetadata,
    game_details_image: ByteArray,
    game_details: Span<GameDetail>,
    settings_details: GameSettingDetails,
    context_details: GameContextDetails,
    token_metadata: TokenMetadata,
    score: u64,
    minted_by: ContractAddress,
    player_name: felt252,
    objective_name: ByteArray,
) -> ByteArray {
    let _token_id = format!("{}", token_id);
    let _game_id = format!("{}", token_metadata.game_id);
    let _score = format!("{}", score);
    let _minted_at = format!("{}", token_metadata.minted_at);
    let _start = format!("{}", token_metadata.lifecycle.start);
    let _end = format!("{}", token_metadata.lifecycle.end);
    let _expired = if token_metadata.lifecycle.end > 0 {
        get_block_timestamp() >= token_metadata.lifecycle.end
    } else {
        false
    };
    let _settings_id = format!("{}", token_metadata.settings_id);
    let address_as_felt: felt252 = minted_by.into();
    let _minted_by = format!("0x{:x}", address_as_felt);

    let mut metadata = JsonImpl::new()
        .add("name", token_name + " #" + _token_id)
        .add("description", token_description)
        .add("image", game_details_image);

    // Core game metadata traits
    let mut attributes = array![
        create_trait("Game ID", _game_id), create_trait("Game Name", game_metadata.name),
        create_trait("Game Developer", game_metadata.developer),
        create_trait("Publisher", game_metadata.publisher),
        create_trait("Genre", game_metadata.genre), create_trait("Minted By", _minted_by),
        create_trait("Score", _score), create_trait("Minted Time", _minted_at),
        create_trait("Start Time", _start), create_trait("End Time", _end),
        create_trait("Expired", bool_to_str(_expired)),
        create_trait("Game Over", bool_to_str(token_metadata.game_over)),
        create_trait("Soulbound", bool_to_str(token_metadata.soulbound)),
        create_trait("Paymaster", bool_to_str(token_metadata.paymaster)),
        create_trait("Metadata", format!("{}", Into::<u16, u32>::into(token_metadata.metadata))),
        create_trait("Settings ID", _settings_id),
    ];

    // Optional settings traits
    if settings_details.name.clone().len() > 0 {
        attributes.append(create_trait("Settings Name", settings_details.name));
    }

    // Optional context traits
    if context_details.name.clone().len() > 0 {
        attributes.append(create_trait("Context Name", context_details.name));
        match context_details.id {
            Option::Some(id) => {
                let _context_id = format!("{}", id);
                attributes.append(create_trait("Context ID", _context_id));
            },
            Option::None => {},
        }
    }

    // Optional objectives traits
    if token_metadata.objective_id != 0 {
        attributes.append(create_trait("Objective ID", format!("{}", token_metadata.objective_id)));
        attributes
            .append(
                create_trait(
                    "Objectives Completed", bool_to_str(token_metadata.completed_objective),
                ),
            );
        if objective_name.len() > 0 {
            attributes.append(create_trait("Objective Name", objective_name));
        }
    }

    // Optional player name trait
    if !player_name.is_zero() {
        let mut _player_name = Default::default();
        _player_name
            .append_word(
                player_name, U256BytesUsedTraitImpl::bytes_used(player_name.into()).into(),
            );
        attributes.append(create_trait("Player Name", _player_name));
    }

    // Add dynamic game details as traits
    let mut game_details_index = 0;
    loop {
        if game_details_index == game_details.len() {
            break;
        }

        let game_detail = game_details.at(game_details_index);
        attributes.append(create_trait(game_detail.name.clone(), game_detail.value.clone()));

        game_details_index += 1;
    }

    let metadata = metadata.add_array("attributes", attributes.span()).build();

    format!("data:application/json;base64,{}", bytes_base64_encode(metadata))
}

#[cfg(test)]
mod tests {
    use game_components_embeddable_game_standard::metagame::extensions::context::structs::{
        GameContext, GameContextDetails,
    };
    use game_components_embeddable_game_standard::minigame::extensions::objectives::structs::{
        GameObjective, GameObjectiveDetails,
    };
    use game_components_embeddable_game_standard::minigame::extensions::settings::structs::{
        GameSetting, GameSettingDetails,
    };
    use game_components_embeddable_game_standard::minigame::structs::GameDetail;
    use game_components_embeddable_game_standard::registry::interface::GameMetadata;
    use game_components_embeddable_game_standard::token::structs::{Lifecycle, TokenMetadata};
    use snforge_std::{start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
    use super::{
        calculate_timeline_progress, create_custom_metadata, create_default_svg,
        timestamp_to_datetime,
    };

    fn default_token_metadata() -> TokenMetadata {
        TokenMetadata {
            game_id: 1,
            settings_id: 1,
            minted_at: 1640995200,
            minted_by: 123,
            lifecycle: Lifecycle { start: 1640995200, end: 1672531200 },
            game_over: false,
            soulbound: false,
            completed_objective: false,
            has_context: false,
            objective_id: 0,
            paymaster: false,
            metadata: 0,
        }
    }

    fn default_settings_details() -> GameSettingDetails {
        GameSettingDetails {
            name: "Standard Mode",
            description: "Default game settings",
            settings: array![GameSetting { name: "Difficulty", value: "Normal" }].span(),
        }
    }

    fn default_objective_details() -> GameObjectiveDetails {
        GameObjectiveDetails {
            name: "Clear All Blocks",
            description: "Complete the puzzle",
            objectives: array![GameObjective { name: "Blocks", value: "0" }].span(),
        }
    }

    fn default_context_details() -> GameContextDetails {
        GameContextDetails {
            name: "Test Context",
            description: "Test context description",
            id: Option::Some(42),
            context: array![GameContext { name: "Tournament", value: "Weekly #5" }].span(),
        }
    }

    fn empty_context_details() -> GameContextDetails {
        GameContextDetails { name: "", description: "", id: Option::None, context: array![].span() }
    }

    #[test]
    fn test_timestamp_to_datetime() {
        // 2022-01-01 00:00:00 UTC
        assert!(timestamp_to_datetime(1640995200) == "2022-01-01 00:00", "epoch 2022-01-01 00:00");
        // 2023-01-01 00:00:00 UTC
        assert!(timestamp_to_datetime(1672531200) == "2023-01-01 00:00", "epoch 2023-01-01 00:00");
        // 0 = no date
        assert!(timestamp_to_datetime(0) == "---", "epoch 0");
        // 1970-01-02 00:00
        assert!(timestamp_to_datetime(86400) == "1970-01-02 00:00", "day after epoch");
        // 2022-01-01 12:30:00 UTC = 1640995200 + 12*3600 + 30*60 = 1640995200 + 45000 =
        // 1641040200
        assert!(timestamp_to_datetime(1641040200) == "2022-01-01 12:30", "midday with minutes");
        // 2022-01-01 23:59:00 UTC = 1640995200 + 23*3600 + 59*60 = 1640995200 + 86340 =
        // 1641081540
        assert!(timestamp_to_datetime(1641081540) == "2022-01-01 23:59", "end of day");
    }

    #[test]
    fn test_calculate_timeline_progress() {
        // Basic cases
        assert!(calculate_timeline_progress(100, 200, 150) == 50, "50%");
        assert!(calculate_timeline_progress(100, 200, 100) == 0, "at start = 0%");
        assert!(calculate_timeline_progress(100, 200, 200) == 100, "at end = 100%");
        assert!(calculate_timeline_progress(100, 200, 50) == 0, "before start = 0%");
        assert!(calculate_timeline_progress(100, 200, 300) == 100, "after end = 100%");
        // Edge: start >= end
        assert!(calculate_timeline_progress(200, 100, 150) == 0, "invalid range = 0%");
        assert!(calculate_timeline_progress(100, 100, 100) == 0, "equal start/end = 0%");
        // Edge: zero range
        assert!(calculate_timeline_progress(0, 0, 0) == 0, "all zeros = 0%");
    }

    #[test]
    fn test_default_svg() {
        start_cheat_block_timestamp_global(1656763200); // midway 2022-2023

        let game_metadata = GameMetadata {
            contract_address: 0x1234567890123456789012345678901234567890.try_into().unwrap(),
            name: "zKube",
            description: "This is as really long description as it can be to test the text wrapping in the SVG generation logic.  It should properly wrap across multiple lines without overflowing the card design. ashdfbyuasdvfyugaysudfbuyasgdf",
            developer: "zKorp",
            publisher: "Starknet Games",
            genre: "Puzzle",
            image: "https://zkube.vercel.app/assets/pwa-512x512.png",
            color: "blue",
            client_url: "https://zkube.vercel.app",
            renderer_address: 0x9876543210987654321098765432109876543210.try_into().unwrap(),
            royalty_fraction: 500,
            created_at: 0,
        };

        let svg_result = create_default_svg(
            game_metadata,
            default_token_metadata(),
            100,
            'test Player',
            default_settings_details(),
            default_objective_details(),
            default_context_details(),
        );

        stop_cheat_block_timestamp_global();

        println!("Default SVG: {}", svg_result);
    }

    #[test]
    fn test_custom_metadata_full() {
        let game_metadata = GameMetadata {
            contract_address: 0x1234567890123456789012345678901234567890.try_into().unwrap(),
            name: "zKube",
            description: "A puzzle game on Starknet",
            developer: "zKorp",
            publisher: "Starknet Games",
            genre: "Puzzle",
            image: "https://zkube.vercel.app/assets/pwa-512x512.png",
            color: "#4f46e5",
            client_url: "https://zkube.vercel.app",
            renderer_address: 0x9876543210987654321098765432109876543210.try_into().unwrap(),
            royalty_fraction: 500,
            created_at: 0,
        };

        let settings_details = GameSettingDetails {
            name: "Difficulty Settings",
            description: "Game difficulty configuration",
            settings: array![
                GameSetting { name: "Difficulty", value: "Hard" },
                GameSetting { name: "Time Limit", value: "300" },
                GameSetting { name: "Lives", value: "3" },
            ]
                .span(),
        };

        let context_details = GameContextDetails {
            name: "Tournament Context",
            description: "Weekly tournament settings",
            id: Option::Some(42),
            context: array![
                GameContext { name: "Tournament", value: "Weekly Challenge #5" },
                GameContext { name: "Prize Pool", value: "1000 STRK" },
                GameContext { name: "Participants", value: "156" },
            ]
                .span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 1,
            settings_id: 1,
            minted_at: 1640995200, // 2022-01-01 00:00:00 UTC
            minted_by: 123,
            lifecycle: Lifecycle { start: 1640995200, end: 1672531200 }, // 2022-2023
            game_over: false,
            soulbound: false,
            completed_objective: true,
            has_context: true,
            objective_id: 5,
            paymaster: false,
            metadata: 0,
        };

        let metadata = create_custom_metadata(
            1000000,
            game_metadata.name.clone(),
            "This is a comprehensive test game token with all features",
            game_metadata,
            "https://zkube.vercel.app/assets/token-image.png",
            array![
                GameDetail { name: "Level", value: "Advanced" },
                GameDetail { name: "Combo Streak", value: "15" },
                GameDetail { name: "Special Power", value: "Lightning Bolt" },
            ]
                .span(),
            settings_details,
            context_details,
            token_metadata,
            95000,
            0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150.try_into().unwrap(),
            'ProGamer2024',
            "Clear All Blocks",
        );

        println!("Full metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_empty_settings() {
        let game_metadata = GameMetadata {
            contract_address: 0x1234567890123456789012345678901234567890.try_into().unwrap(),
            name: "Simple Game",
            description: "A basic game",
            developer: "Indie Dev",
            publisher: "Self Published",
            genre: "Arcade",
            image: "https://example.com/game.png",
            color: "#ffffff",
            client_url: "https://example.com/play",
            renderer_address: 0x9876543210987654321098765432109876543210.try_into().unwrap(),
            royalty_fraction: 250,
            created_at: 0,
        };

        // Empty settings
        let settings_details = GameSettingDetails {
            name: "", description: "", settings: [].span(),
        };

        // Empty context
        let context_details = GameContextDetails {
            name: "", description: "", id: Option::None, context: [].span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 1,
            settings_id: 0,
            minted_at: 1640995200,
            minted_by: 456,
            lifecycle: Lifecycle { start: 1640995200, end: 1672531200 },
            game_over: true,
            soulbound: true,
            completed_objective: false,
            has_context: false,
            objective_id: 0,
            paymaster: false,
            metadata: 0,
        };

        let metadata = create_custom_metadata(
            2000000,
            game_metadata.name.clone(),
            "Basic game token with minimal features",
            game_metadata,
            "https://example.com/basic-token.png",
            [].span(), // No game details
            settings_details,
            context_details,
            token_metadata,
            1200,
            0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150.try_into().unwrap(),
            0, // No player name
            "" // No objective
        );

        println!("Empty settings metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_partial_context() {
        let game_metadata = GameMetadata {
            contract_address: 0x1111111111111111111111111111111111111111.try_into().unwrap(),
            name: "Context Game",
            description: "Game with partial context",
            developer: "Context Dev",
            publisher: "Context Publisher",
            genre: "Strategy",
            image: "https://example.com/context-game.png",
            color: "#00ff00",
            client_url: "https://example.com/context",
            renderer_address: 0x2222222222222222222222222222222222222222.try_into().unwrap(),
            royalty_fraction: 750,
            created_at: 0,
        };

        let settings_details = GameSettingDetails {
            name: "Basic Settings",
            description: "Simple game settings",
            settings: array![GameSetting { name: "Mode", value: "Single Player" }].span(),
        };

        // Context with name but no ID
        let context_details = GameContextDetails {
            name: "Casual Mode",
            description: "Relaxed gameplay mode",
            id: Option::None,
            context: array![GameContext { name: "Mode Type", value: "Casual" }].span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 3,
            settings_id: 2,
            minted_at: 1650000000,
            minted_by: 789,
            lifecycle: Lifecycle { start: 1650000000, end: 1680000000 },
            game_over: false,
            soulbound: false,
            completed_objective: false,
            has_context: true,
            objective_id: 10,
            paymaster: false,
            metadata: 0,
        };

        let metadata = create_custom_metadata(
            3000000,
            game_metadata.name.clone(),
            "Game token with partial context information",
            game_metadata,
            "https://example.com/partial-context.png",
            array![GameDetail { name: "Progress", value: "50%" }].span(),
            settings_details,
            context_details,
            token_metadata,
            7500,
            0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150.try_into().unwrap(),
            'CasualPlayer',
            "Win 10 Matches",
        );

        println!("Partial context metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_single_objective() {
        let game_metadata = GameMetadata {
            contract_address: 0x3333333333333333333333333333333333333333.try_into().unwrap(),
            name: "Single Objective Game",
            description: "Game with one objective",
            developer: "Solo Dev",
            publisher: "Indie Games",
            genre: "Adventure",
            image: "https://example.com/adventure.png",
            color: "#ff6600",
            client_url: "https://example.com/adventure",
            renderer_address: 0x4444444444444444444444444444444444444444.try_into().unwrap(),
            royalty_fraction: 1000,
            created_at: 0,
        };

        let settings_details = GameSettingDetails {
            name: "Adventure Settings",
            description: "Configuration for adventure mode",
            settings: array![
                GameSetting { name: "Difficulty", value: "Medium" },
                GameSetting { name: "Hints", value: "Enabled" },
            ]
                .span(),
        };

        let context_details = GameContextDetails {
            name: "Adventure Quest",
            description: "Epic adventure questline",
            id: Option::Some(1),
            context: array![
                GameContext { name: "Chapter", value: "The Beginning" },
                GameContext { name: "Location", value: "Mystical Forest" },
            ]
                .span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 4,
            settings_id: 3,
            minted_at: 1660000000,
            minted_by: 101,
            lifecycle: Lifecycle { start: 1660000000, end: 1690000000 },
            game_over: false,
            soulbound: true,
            completed_objective: true,
            has_context: true,
            objective_id: 100,
            paymaster: false,
            metadata: 0,
        };

        let metadata = create_custom_metadata(
            4000000,
            game_metadata.name.clone(),
            "Adventure game token with single objective",
            game_metadata,
            "https://example.com/quest-token.png",
            array![
                GameDetail { name: "Quest Status", value: "In Progress" },
                GameDetail { name: "Items Collected", value: "5/10" },
                GameDetail { name: "Experience", value: "2500 XP" },
            ]
                .span(),
            settings_details,
            context_details,
            token_metadata,
            85000,
            0x065d2AB17338b5AffdEbAF95E2D79834B5f30Bac596fF55563c62C3c98700150.try_into().unwrap(),
            'AdventureSeeker',
            "Complete the Quest",
        );

        println!("Single objective metadata: {}", metadata);
    }

    #[test]
    fn test_custom_metadata_edge_cases() {
        let game_metadata = GameMetadata {
            contract_address: 0x5555555555555555555555555555555555555555.try_into().unwrap(),
            name: "Edge Case Game",
            description: "Testing edge cases",
            developer: "Test Dev",
            publisher: "Test Publisher",
            genre: "Test",
            image: "https://example.com/test.png",
            color: "#000000",
            client_url: "https://example.com/test",
            renderer_address: 0x6666666666666666666666666666666666666666.try_into().unwrap(),
            royalty_fraction: 10000,
            created_at: 0,
        };

        let settings_details = GameSettingDetails {
            name: "Test Settings",
            description: "Edge case testing",
            settings: array![
                GameSetting { name: "Edge Case 1", value: "" }, // Empty value
                GameSetting { name: "", value: "Edge Case 2" }, // Empty name
                GameSetting { name: "Normal", value: "Value" },
            ]
                .span(),
        };

        let context_details = GameContextDetails {
            name: "Test Context",
            description: "Edge case context",
            id: Option::Some(999999), // Large ID
            context: array![
                GameContext { name: "Max Value", value: "999999999" },
                GameContext { name: "Special Chars", value: "!@#$%^&*()" },
                GameContext { name: "ASCII Only", value: "Game Trophy Winner" },
            ]
                .span(),
        };

        let token_metadata = TokenMetadata {
            game_id: 999,
            settings_id: 999,
            minted_at: 0, // Minimum timestamp
            minted_by: 0, // Minimum minter ID
            lifecycle: Lifecycle { start: 0, end: 4294967295 }, // Max u32
            game_over: true,
            soulbound: true,
            completed_objective: true,
            has_context: true,
            objective_id: 1,
            paymaster: false,
            metadata: 0,
        };

        let metadata = create_custom_metadata(
            18446744073709551615, // Max u64
            game_metadata.name.clone(),
            "Edge case testing with extreme values and special characters !@#$%^&*()",
            game_metadata,
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==",
            array![
                GameDetail { name: "Zero Score", value: "0" },
                GameDetail { name: "Max Score", value: "4294967295" },
                GameDetail { name: "Negative-like", value: "-1" },
                GameDetail { name: "Float-like", value: "3.14159" },
                GameDetail { name: "Boolean-like", value: "true" },
                GameDetail { name: "Special Chars", value: "!@#$%^&*()" },
            ]
                .span(),
            settings_details,
            context_details,
            token_metadata,
            18446744073709551615, // Max u64 score
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF.try_into().unwrap(), // Max address
            'MAX_FELT_VALUE_TEST',
            "Edge Case Objective",
        );

        println!("Edge cases metadata: {}", metadata);
    }
}
