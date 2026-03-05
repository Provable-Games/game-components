use core::array::SpanTrait;
use core::clone::Clone;
use core::num::traits::Zero;
use core::traits::Into;
use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContextDetails;
use game_components_embeddable_game_standard::minigame::extensions::objectives::structs::GameObjectiveDetails;
use game_components_embeddable_game_standard::minigame::extensions::settings::structs::GameSettingDetails;
use game_components_embeddable_game_standard::registry::interface::GameMetadata;
use game_components_embeddable_game_standard::token::structs::TokenMetadata;
use starknet::get_block_timestamp;
use crate::utils::encoding::{U256BytesUsedTraitImpl, felt252_to_byte_array};

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

fn icon_check(
    x: ByteArray, y: ByteArray, w: ByteArray, h: ByteArray, color: @ByteArray,
) -> ByteArray {
    "<svg x='"
        + x
        + "' y='"
        + y
        + "' width='"
        + w
        + "' height='"
        + h
        + "' viewBox='0 0 16 16'><path fill='none' stroke='"
        + color.clone()
        + "' stroke-width='2' stroke-linecap='round' d='M3 8l3.5 3.5L13 5'/></svg>"
}

fn icon_x(x: ByteArray, y: ByteArray, w: ByteArray, h: ByteArray, color: @ByteArray) -> ByteArray {
    "<svg x='"
        + x
        + "' y='"
        + y
        + "' width='"
        + w
        + "' height='"
        + h
        + "' viewBox='0 0 16 16'><path fill='none' stroke='"
        + color.clone()
        + "' stroke-width='2' stroke-linecap='round' d='M4 4l8 8M12 4l-8 8'/></svg>"
}

fn icon_target(
    x: ByteArray, y: ByteArray, w: ByteArray, h: ByteArray, color: @ByteArray,
) -> ByteArray {
    "<svg x='"
        + x
        + "' y='"
        + y
        + "' width='"
        + w
        + "' height='"
        + h
        + "' viewBox='0 0 16 16'><circle fill='none' stroke='"
        + color.clone()
        + "' stroke-width='1.5' cx='8' cy='8' r='6'/><circle fill='none' stroke='"
        + color.clone()
        + "' stroke-width='1.5' cx='8' cy='8' r='3'/><circle fill='"
        + color.clone()
        + "' cx='8' cy='8' r='1.5'/></svg>"
}

fn icon_flag(
    x: ByteArray, y: ByteArray, w: ByteArray, h: ByteArray, color: @ByteArray,
) -> ByteArray {
    "<svg x='"
        + x
        + "' y='"
        + y
        + "' width='"
        + w
        + "' height='"
        + h
        + "' viewBox='0 0 16 16'><path fill='none' stroke='"
        + color.clone()
        + "' stroke-width='1.5' stroke-linecap='round' d='M4 14V2'/><path fill='"
        + color.clone()
        + "' d='M4 2l8 3-8 3z'/></svg>"
}

pub fn create_default_svg(
    game_metadata: GameMetadata,
    token_metadata: TokenMetadata,
    score: u64,
    player_name: felt252,
    settings_details: GameSettingDetails,
    objective_details: GameObjectiveDetails,
    context_details: GameContextDetails,
    client_url: ByteArray,
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
            @"<svg xmlns='http://www.w3.org/2000/svg' width='590' height='680' viewBox='-60 -40 590 680'>",
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

    // Connector pin gradient and pattern
    svg
        .append(
            @"<linearGradient id='pinGold' x1='0' y1='0' x2='0' y2='1'><stop offset='0%' stop-color='#d4a843'/><stop offset='50%' stop-color='#f0d060'/><stop offset='100%' stop-color='#b8922e'/></linearGradient>",
        );
    svg
        .append(
            @"<pattern id='cpins' width='20' height='32' patternUnits='userSpaceOnUse'><rect x='4' y='0' width='12' height='32' rx='2' fill='url(#pinGold)'/></pattern>",
        );

    // Clip path for inward-only border stroke
    svg.append(@"<clipPath id='card-clip'><rect width='470' height='600' rx='16'/></clipPath>");

    // Styles with card rotation and edge depth
    svg
        .append(
            @"<style>.l{fill:#c9c9d1;font-size:13px;letter-spacing:0.5px}.v{fill:#fff;font-size:16px}.vs{fill:#fff;font-size:13px}text{font-family:'Courier New',Courier,monospace;text-transform:uppercase}@keyframes tilt{0%,100%{transform:rotateY(-20deg)}50%{transform:rotateY(20deg)}}@keyframes sl{0%,100%{opacity:1}20%{opacity:0.15}25%,75%{opacity:0}80%{opacity:0.15}}@keyframes sr{0%,25%,75%,100%{opacity:0}30%{opacity:0.15}50%{opacity:1}70%{opacity:0.15}}.card{animation:tilt 6s ease-in-out infinite;transform-origin:235px 300px}.el{fill:#3a3a42;animation:sl 6s ease-in-out infinite}.er{fill:#3a3a42;animation:sr 6s ease-in-out infinite}</style>",
        );
    svg.append(@"</defs>");

    // Card group with rotation and 3D depth
    svg.append(@"<g class='card'>");

    // Left edge (visible when card rotates left)
    svg.append(@"<path class='el' d='M-12 17 Q-12 1 16 1 L16 599 Q-12 599 -12 583 Z'/>");
    // Right edge (visible when card rotates right)
    svg.append(@"<path class='er' d='M482 17 Q482 1 454 1 L454 599 Q482 599 482 583 Z'/>");

    // Background layers
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#pin)'/>");
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#vignette)'/>");
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#scan)'/>");
    // Shimmer sweep
    svg.append(@"<rect width='470' height='600' rx='16' fill='url(#shimmer)'/>");
    // Animated gradient border (on top of all fills)
    svg
        .append(
            @"<rect width='470' height='600' rx='16' fill='none' stroke='url(#accentGrad)' stroke-width='20' clip-path='url(#card-clip)'/>",
        );

    // ── Header: EGS logo placeholder + game name + game ID ──
    svg.append(@"<rect x='18' y='24' width='44' height='44' rx='8' fill='#000'/>");
    svg
        .append(
            @"<svg x='23' y='33' width='34' height='22' viewBox='0 0 415 287'><path fill='#fff' d='M134 0q21 0 40 8a104 104 0 0 1 56 53 91 91 0 0 1 0 77q-8 19-23 32-14 14-33 21-19 8-40 8h-33l-33-57h66q9 0 17-3t14-9l10-15q3-9 3-20 0-8-3-17l-10-15-14-10q-9-4-17-4H59v234H0V0z'/><path fill='#fff' fill-rule='evenodd' d='m415 131-2-12H306l-34 52h79q-3 15-11 27l-18 20q-10 9-24 14-14 4-29 4a86 86 0 0 1-56-20v60a155 155 0 0 0 160-31 140 140 0 0 0 42-102zM210 11q-22 10-40 25l42 27v8a88 88 0 0 1 103-8l28-44Q310 0 269 0q-31 0-59 11' clip-rule='evenodd' opacity='.4'/></svg>",
        );

    // Game name
    svg.append(@"<text x='72' y='38' style='fill:#fff;font-size:22px;letter-spacing:1px'>");
    svg += _game_name;
    svg.append(@"</text>");
    // Developer + Genre
    svg
        .append(
            @"<text x='72' y='56' style='fill:#888;font-size:9px;letter-spacing:1px'>DEVELOPER </text>",
        );
    svg.append(@"<text x='138' y='56' class='l'>");
    svg += _developer;
    svg.append(@"</text>");
    svg
        .append(
            @"<text x='72' y='70' style='fill:#888;font-size:9px;letter-spacing:1px'>GENRE </text>",
        );
    svg.append(@"<text x='112' y='70' class='l' style='font-size:11px'>");
    svg += _genre;
    svg.append(@"</text>");

    // Player name (top right)
    svg
        .append(
            @"<text x='440' y='41' text-anchor='end' style='fill:#fff;font-size:18px;letter-spacing:1px'>",
        );
    svg += _player_name.clone();
    svg.append(@"</text>");

    // Accent separator
    svg.append(@"<line x1='25' y1='82' x2='445' y2='82' stroke='");
    svg.append(@accent);
    svg.append(@"' stroke-width='3' opacity='0.5'/>");

    // ── Game image area (centered square) ──
    svg
        .append(
            @"<rect x='175' y='88' width='120' height='120' rx='10' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg
        .append(
            @"<foreignObject x='180' y='93' width='110' height='110'><xhtml:img xmlns:xhtml='http://www.w3.org/1999/xhtml' src='",
        );
    svg += game_metadata.image;
    svg.append(@"' style='width:100%;height:100%'/></foreignObject>");

    // ── Status Badge Panels flanking game image (2 left, 2 right) ──
    // Badge 1: STATUS (top-left, y:88-144)
    svg
        .append(
            @"<rect x='25' y='88' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.game_over {
        // Game Over: amber skull
        svg.append(@"<rect x='25' y='88' width='4' height='56' rx='2' fill='#f59e0b'/>");
        svg
            .append(
                @"<svg x='39' y='102' width='14' height='14' viewBox='0 0 16 16'><circle fill='#f59e0b' cx='8' cy='6.5' r='5.5'/><rect fill='#f59e0b' x='5' y='11' width='6' height='4' rx='1'/><circle fill='#1e1e22' cx='6' cy='6' r='1.5'/><circle fill='#1e1e22' cx='10' cy='6' r='1.5'/><ellipse fill='#1e1e22' cx='8' cy='9' rx='1' ry='0.7'/></svg>",
            );
        svg
            .append(
                @"<text x='58' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>STATUS</text>",
            );
        svg.append(@"<text x='39' y='132' style='fill:#fff;font-size:13px'>GAME OVER</text>");
    } else if token_metadata.lifecycle.end > 0 && current_ts >= token_metadata.lifecycle.end {
        // Expired: red hourglass
        svg.append(@"<rect x='25' y='88' width='4' height='56' rx='2' fill='#ef4444'/>");
        svg
            .append(
                @"<svg x='39' y='102' width='14' height='14' viewBox='0 0 16 16'><path fill='#ef4444' d='M4 1h8v4L9 8l3 3v4H4v-4l3-3-3-3z'/><rect fill='#1e1e22' x='5' y='2' width='6' height='2'/><rect fill='#1e1e22' x='5' y='12' width='6' height='2'/></svg>",
            );
        svg
            .append(
                @"<text x='58' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>STATUS</text>",
            );
        svg.append(@"<text x='39' y='132' style='fill:#fff;font-size:13px'>EXPIRED</text>");
    } else if token_metadata.lifecycle.start > 0 && current_ts < token_metadata.lifecycle.start {
        // Not Started: blue pause
        svg.append(@"<rect x='25' y='88' width='4' height='56' rx='2' fill='#3b82f6'/>");
        svg
            .append(
                @"<svg x='39' y='102' width='14' height='14' viewBox='0 0 16 16'><rect fill='#3b82f6' x='3' y='2' width='4' height='12' rx='1'/><rect fill='#3b82f6' x='9' y='2' width='4' height='12' rx='1'/></svg>",
            );
        svg
            .append(
                @"<text x='58' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>STATUS</text>",
            );
        svg.append(@"<text x='39' y='132' style='fill:#fff;font-size:13px'>NOT STARTED</text>");
    } else {
        // Active: green play
        svg.append(@"<rect x='25' y='88' width='4' height='56' rx='2' fill='#10b981'/>");
        svg
            .append(
                @"<svg x='39' y='102' width='14' height='14' viewBox='0 0 16 16'><path fill='#10b981' d='M4 2l10 6-10 6z'/></svg>",
            );
        svg
            .append(
                @"<text x='58' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>STATUS</text>",
            );
        svg.append(@"<text x='39' y='132' style='fill:#fff;font-size:13px'>ACTIVE</text>");
    }

    // Badge 2: SOULBOUND (bottom-left, y:152-208)
    svg
        .append(
            @"<rect x='25' y='152' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.soulbound {
        svg.append(@"<rect x='25' y='152' width='4' height='56' rx='2' fill='#a855f7'/>");
        svg
            .append(
                @"<svg x='39' y='166' width='14' height='14' viewBox='0 0 16 16'><rect fill='#a855f7' x='3' y='7' width='10' height='7' rx='1'/><path fill='none' stroke='#a855f7' stroke-width='1.5' d='M5 7V5a3 3 0 016 0v2'/></svg>",
            );
        svg
            .append(
                @"<text x='58' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OWNERSHIP</text>",
            );
        svg.append(@"<text x='39' y='196' style='fill:#fff;font-size:13px'>SOULBOUND</text>");
    } else {
        svg.append(@"<rect x='25' y='152' width='4' height='56' rx='2' fill='#10b981'/>");
        svg
            .append(
                @"<svg x='39' y='166' width='14' height='14' viewBox='0 0 16 16'><path fill='none' stroke='#10b981' stroke-width='2' stroke-linecap='round' stroke-linejoin='round' d='M2 5h12M10 1l4 4-4 4'/><path fill='none' stroke='#10b981' stroke-width='2' stroke-linecap='round' stroke-linejoin='round' d='M14 11H2M6 7l-4 4 4 4'/></svg>",
            );
        svg
            .append(
                @"<text x='58' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OWNERSHIP</text>",
            );
        svg.append(@"<text x='39' y='196' style='fill:#fff;font-size:13px'>TRANSFERABLE</text>");
    }

    // Badge 3: PAYMASTER (top-right, y:88-144)
    svg
        .append(
            @"<rect x='303' y='88' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.paymaster {
        svg.append(@"<rect x='303' y='88' width='4' height='56' rx='2' fill='#10b981'/>");
        svg += icon_check("317", "102", "14", "14", @"#10b981");
        svg
            .append(
                @"<text x='336' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>PAYMASTER</text>",
            );
        svg.append(@"<text x='317' y='132' style='fill:#fff;font-size:13px'>FREE GAS</text>");
    } else {
        svg.append(@"<rect x='303' y='88' width='4' height='56' rx='2' fill='#555'/>");
        svg += icon_x("317", "102", "14", "14", @"#555");
        svg
            .append(
                @"<text x='336' y='111' style='fill:#888;font-size:9px;letter-spacing:1px'>PAYMASTER</text>",
            );
        svg.append(@"<text x='317' y='132' style='fill:#888;font-size:13px'>PAID GAS</text>");
    }

    // Badge 4: OBJECTIVE (bottom-right, y:152-208)
    svg
        .append(
            @"<rect x='303' y='152' width='142' height='56' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    if token_metadata.completed_objective {
        // Objective complete: green check
        svg.append(@"<rect x='303' y='152' width='4' height='56' rx='2' fill='#10b981'/>");
        svg += icon_check("317", "166", "14", "14", @"#10b981");
        svg
            .append(
                @"<text x='336' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OBJECTIVE</text>",
            );
        svg.append(@"<text x='317' y='196' style='fill:#fff;font-size:13px'>COMPLETE</text>");
    } else if token_metadata.objective_id > 0 && token_metadata.game_over {
        // Objective not complete and game over: red x-mark (failed)
        svg.append(@"<rect x='303' y='152' width='4' height='56' rx='2' fill='#ef4444'/>");
        svg += icon_x("317", "166", "14", "14", @"#ef4444");
        svg
            .append(
                @"<text x='336' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OBJECTIVE</text>",
            );
        svg.append(@"<text x='317' y='196' style='fill:#fff;font-size:13px'>FAILED</text>");
    } else if token_metadata.objective_id > 0 {
        // Objective assigned but not complete: amber target
        svg.append(@"<rect x='303' y='152' width='4' height='56' rx='2' fill='#f59e0b'/>");
        svg += icon_target("317", "166", "14", "14", @"#f59e0b");
        svg
            .append(
                @"<text x='336' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OBJECTIVE</text>",
            );
        svg.append(@"<text x='317' y='196' style='fill:#fff;font-size:13px'>PENDING</text>");
    } else {
        // No objective: greyed out
        svg.append(@"<rect x='303' y='152' width='4' height='56' rx='2' fill='#555'/>");
        svg += icon_target("317", "166", "14", "14", @"#555");
        svg
            .append(
                @"<text x='336' y='175' style='fill:#888;font-size:9px;letter-spacing:1px'>OBJECTIVE</text>",
            );
        svg.append(@"<text x='317' y='196' style='fill:#888;font-size:13px'>NONE</text>");
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
            let y_pos: u32 = 232 + line_num * 14;
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

    // ── Two-Col Panels Row 1 (y:276-326): SCORE | CLIENT URL ──
    // Score panel with accent left-border
    svg
        .append(
            @"<rect x='25' y='276' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='276' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<svg x='37' y='285' width='14' height='14' viewBox='0 0 16 16'><path fill='#c9c9d1' d='M8 1l2.2 4.5 5 .7-3.6 3.5.8 5L8 12.4 3.6 14.7l.8-5L.8 6.2l5-.7z'/></svg>",
        );
    svg.append(@"<text x='56' y='297' class='l'>SCORE</text>");
    svg.append(@"<text x='37' y='316' class='v'>");
    svg += _score;
    svg.append(@"</text>");

    // Client URL panel with link icon
    svg
        .append(
            @"<rect x='240' y='276' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='240' y='276' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<svg x='252' y='285' width='14' height='14' viewBox='0 0 16 16'><path fill='none' stroke='#c9c9d1' stroke-width='2' stroke-linecap='round' d='M6.5 9.5a3.5 3.5 0 005 0l2-2a3.5 3.5 0 00-5-5l-1 1'/><path fill='none' stroke='#c9c9d1' stroke-width='2' stroke-linecap='round' d='M9.5 6.5a3.5 3.5 0 00-5 0l-2 2a3.5 3.5 0 005 5l1-1'/></svg>",
        );
    svg.append(@"<text x='271' y='297' class='l'>CLIENT URL</text>");
    svg.append(@"<text x='252' y='316' class='vs' style='font-size:9px'>");
    if client_url.len() > 0 {
        svg += client_url;
    } else {
        svg.append(@"---");
    }
    svg.append(@"</text>");

    // ── Two-Col Panels Row 2 (y:334-384): SETTINGS | OBJECTIVE ──
    // Settings panel with gear icon
    svg
        .append(
            @"<rect x='25' y='334' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='334' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<svg x='37' y='343' width='14' height='14' viewBox='0 0 16 16'><path fill='#c9c9d1' d='M6.8 1h2.4l.4 2 .7.3 1.7-1.1 1.7 1.7-1.1 1.7.3.7 2 .4v2.4l-2 .4-.3.7 1.1 1.7-1.7 1.7-1.7-1.1-.7.3-.4 2H6.8l-.4-2-.7-.3-1.7 1.1-1.7-1.7 1.1-1.7-.3-.7-2-.4V6.8l2-.4.3-.7L3.2 4l1.7-1.7 1.7 1.1.7-.3z'/><circle fill='#1e1e22' cx='8' cy='8' r='2.5'/></svg>",
        );
    svg.append(@"<text x='56' y='355' class='l'>SETTINGS</text>");
    svg.append(@"<text x='37' y='374' class='vs'>");
    svg += _settings_name;
    svg.append(@"</text>");

    // Objective panel with target icon
    svg
        .append(
            @"<rect x='240' y='334' width='205' height='50' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='240' y='334' width='4' height='50' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg += icon_target("252", "343", "14", "14", @"#c9c9d1");
    svg.append(@"<text x='271' y='355' class='l'>OBJECTIVE</text>");
    svg.append(@"<text x='252' y='374' class='vs'>");
    svg += _objective_name;
    svg.append(@"</text>");

    // ── Timeline Bordered Section (y:392-450) ──
    svg
        .append(
            @"<rect x='25' y='392' width='420' height='58' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='392' width='4' height='58' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg
        .append(
            @"<svg x='37' y='400' width='14' height='14' viewBox='0 0 16 16'><circle fill='none' stroke='#c9c9d1' stroke-width='1.5' cx='8' cy='8' r='6'/><path fill='none' stroke='#c9c9d1' stroke-width='1.5' stroke-linecap='round' d='M8 4v4l2.5 2.5'/></svg>",
        );
    svg.append(@"<text x='56' y='412' class='l'>TIMELINE</text>");
    // Start flag + datetime
    svg += icon_flag("37", "418", "12", "12", @"#10b981");
    svg.append(@"<text x='52' y='428' style='fill:#888;font-size:10px'>");
    svg += _start;
    svg.append(@"</text>");
    // End flag + datetime (right-aligned)
    svg.append(@"<text x='419' y='428' text-anchor='end' style='fill:#888;font-size:10px'>");
    svg += _end;
    svg.append(@"</text>");
    svg += icon_flag("421", "418", "12", "12", @"#ef4444");
    // Track background
    svg.append(@"<rect x='37' y='438' width='396' height='6' rx='3' fill='#3a3a40'/>");
    // Filled portion
    svg.append(@"<rect x='37' y='438' width='");
    svg += format!("{}", fill_width);
    svg.append(@"' height='6' rx='3' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    // Marker circle
    svg.append(@"<circle cx='");
    svg += format!("{}", marker_x);
    svg.append(@"' cy='441' r='5' fill='");
    svg.append(@accent);
    svg.append(@"' stroke='#fff' stroke-width='1.5'/>");

    // ── Context Bordered Section (y:458-526) ──
    svg
        .append(
            @"<rect x='25' y='458' width='420' height='68' rx='8' fill='url(#panel)' stroke='#3a3a40' stroke-width='1'/>",
        );
    svg.append(@"<rect x='25' y='458' width='4' height='68' rx='2' fill='");
    svg.append(@accent);
    svg.append(@"'/>");
    svg.append(@"<text x='37' y='476' class='l'>CONTEXT</text>");
    svg.append(@"<text x='112' y='476' class='vs'>");
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
        let y_base: u32 = 491;
        loop {
            if ctx_i >= max_entries {
                break;
            }
            let entry = ctx_span.at(ctx_i);
            let y_pos = y_base + ctx_i * 15;
            svg.append(@"<text x='37' y='");
            svg += format!("{}", y_pos);
            svg.append(@"' style='fill:#888;font-size:10px'>");
            svg += felt252_to_byte_array(*entry.name);
            svg.append(@": ");
            svg += felt252_to_byte_array(*entry.value);
            svg.append(@"</text>");
            ctx_i += 1;
        };
    }

    // ── Footer ──
    svg.append(@"<line x1='25' y1='538' x2='445' y2='538' stroke='");
    svg.append(@accent);
    svg.append(@"' stroke-width='3' opacity='0.5'/>");
    // Royalty (left) + Minted (right)
    svg
        .append(
            @"<text x='25' y='554' style='fill:#888;font-size:10px;letter-spacing:1px'>ROYALTY: ",
        );
    svg += _royalty;
    svg.append(@"</text>");
    svg
        .append(
            @"<text x='445' y='554' text-anchor='end' style='fill:#888;font-size:10px;letter-spacing:1px'>MINTED ",
        );
    svg += _minted_at;
    svg.append(@"</text>");
    // Connector pins (cartridge bottom, inside card)
    svg.append(@"<rect x='30' y='564' width='410' height='36' fill='#111114'/>");
    svg.append(@"<rect x='38' y='568' width='394' height='32' fill='url(#cpins)'/>");

    svg.append(@"</g>"); // close card group
    svg.append(@"</svg>");

    "data:image/svg+xml;utf8," + svg
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
    use game_components_embeddable_game_standard::registry::interface::GameMetadata;
    use game_components_embeddable_game_standard::token::structs::{Lifecycle, TokenMetadata};
    use snforge_std::{start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
    use super::{calculate_timeline_progress, create_default_svg, timestamp_to_datetime};

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
            settings: array![GameSetting { name: 'Difficulty', value: 'Normal' }].span(),
        }
    }

    fn default_objective_details() -> GameObjectiveDetails {
        GameObjectiveDetails {
            name: "Clear All Blocks",
            description: "Complete the puzzle",
            objectives: array![GameObjective { name: 'Blocks', value: '0' }].span(),
        }
    }

    fn default_context_details() -> GameContextDetails {
        GameContextDetails {
            name: "Test Context",
            description: "Test context description",
            id: Option::Some(42),
            context: array![GameContext { name: 'Tournament', value: 'Weekly #5' }].span(),
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
            skills_address: 0.try_into().unwrap(),
            created_at: 0,
            version: 0,
        };

        let svg_result = create_default_svg(
            game_metadata,
            default_token_metadata(),
            100,
            'test Player',
            default_settings_details(),
            default_objective_details(),
            default_context_details(),
            "https://zkube.vercel.app",
        );

        stop_cheat_block_timestamp_global();

        println!("Default SVG: {}", svg_result);
    }
}
