// SPDX-License-Identifier: BUSL-1.1

#[dojo::model]
#[derive(Drop, Serde)]
pub struct Leaderboard {
    #[key]
    pub tournament_id: u64,
    pub token_ids: Array<u64>,
}