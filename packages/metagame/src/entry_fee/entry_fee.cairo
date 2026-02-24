// SPDX-License-Identifier: BUSL-1.1

/// Pure Cairo library for entry fee operations.
/// This library provides core entry fee functionality without storage dependencies.
/// Currently, most pure logic (StorePacking, share math) already lives in structs.cairo
/// and libs/share_math.cairo. This module serves as the namespace for the pure library layer.
pub mod entry_fee {}
