use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use crate::constants::VERSION;
use crate::minigame::models::minigame::{
    Score, ScoreObjective, ScoreObjectiveCount, Settings, SettingsCounter, SettingsDetails,
};

#[derive(Copy, Drop)]
pub struct Store {
    world: WorldStorage,
}

#[generate_trait]
pub impl StoreImpl of StoreTrait {
    #[inline(always)]
    fn new(world: WorldStorage) -> Store {
        (Store { world })
    }

    //
    // Getters
    //

    #[inline(always)]
    fn get_score(self: Store, game_id: u64) -> u32 {
        let score: Score = self.world.read_model(game_id);
        score.score
    }

    #[inline(always)]
    fn get_objective_score(self: Store, objective_id: u32) -> ScoreObjective {
        (self.world.read_model(objective_id))
    }

    #[inline(always)]
    fn get_objective_count(self: Store) -> u32 {
        let objective_count: ScoreObjectiveCount = self.world.read_model(VERSION);
        objective_count.count
    }

    #[inline(always)]
    fn get_settings(self: Store, settings_id: u32) -> Settings {
        (self.world.read_model(settings_id))
    }

    #[inline(always)]
    fn get_settings_details(self: Store, id: u32) -> SettingsDetails {
        (self.world.read_model(id))
    }

    #[inline(always)]
    fn get_settings_count(self: Store) -> u32 {
        let settings_count: SettingsCounter = self.world.read_model(VERSION);
        settings_count.count
    }

    //
    // Setters
    //

    // Game

    #[inline(always)]
    fn set_score(ref self: Store, model: @Score) {
        self.world.write_model(model);
    }

    #[inline(always)]
    fn set_objective_score(ref self: Store, model: @ScoreObjective) {
        self.world.write_model(model);
    }

    #[inline(always)]
    fn set_objective_count(ref self: Store, count: u32) {
        self.world.write_model(@ScoreObjectiveCount { key: VERSION, count });
    }

    #[inline(always)]
    fn set_settings(ref self: Store, model: @Settings) {
        self.world.write_model(model);
    }

    #[inline(always)]
    fn set_settings_details(ref self: Store, model: @SettingsDetails) {
        self.world.write_model(model);
    }

    #[inline(always)]
    fn set_settings_count(ref self: Store, count: u32) {
        self.world.write_model(@SettingsCounter { key: VERSION, count });
    }
}
