// SPDX-License-Identifier: BUSL-1.1

#[derive(Drop, Serde)]
pub struct Leaderboard {
    pub tournament_id: u64,
    pub token_ids: Array<u64>,
}