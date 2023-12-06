//! This module embeds and exports all the assets.

pub const terrain = @embedFile("terrain.png");
pub const terrain_vs = @embedFile("terrain.vs");
pub const terrain_fs = @embedFile("terrain.fs");
