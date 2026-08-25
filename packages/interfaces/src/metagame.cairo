// Metagame interfaces module

pub mod context;
pub mod core;
pub use context::{
    IMETAGAME_CONTEXT_ID, IMetagameContext, IMetagameContextDetails,
    IMetagameContextDetailsDispatcher, IMetagameContextDetailsDispatcherTrait,
    IMetagameContextDispatcher, IMetagameContextDispatcherTrait, IMetagameContextSVG,
    IMetagameContextSVGDispatcher, IMetagameContextSVGDispatcherTrait,
};

