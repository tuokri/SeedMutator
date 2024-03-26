class SeedMutatorConfig extends Object
    notplaceable
    config(Mutator_Seed_Config);

// Maximum number of bots to add to the game.
var(SeedMutator) config int BotLimit;
// Threshold to dynamically start adding bots.
// Number of players as percentage of maximum players.
var(SeedMutator) config float DynamicBotAddThreshold;
// Config version. Updated in case of backwards-incompatible
// changes in mutator code.
var(SeedMutator) config int ConfigVersion;
