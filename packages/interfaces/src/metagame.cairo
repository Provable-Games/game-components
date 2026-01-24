// Metagame interfaces module

pub mod callback;
pub mod context;
pub mod core;
pub use callback::{
    IMETAGAME_CALLBACK_ID, IMetagameCallback, IMetagameCallbackDispatcher,
    IMetagameCallbackDispatcherTrait,
};
pub use context::{
    IMETAGAME_CONTEXT_ID, IMetagameContext, IMetagameContextDetails,
    IMetagameContextDetailsDispatcher, IMetagameContextDetailsDispatcherTrait,
    IMetagameContextDispatcher, IMetagameContextDispatcherTrait, IMetagameContextSVG,
    IMetagameContextSVGDispatcher, IMetagameContextSVGDispatcherTrait,
};

// Re-export commonly used items at top level
pub use core::{IMETAGAME_ID, IMetagame, IMetagameDispatcher, IMetagameDispatcherTrait};
