# Seed Mutator

Seeding utilities for Rising Storm 2: Vietnam dedicated server operators.

## Config Options

| Option                               | Description                                                                                     | Value      |
| ------------------------------------ | ----------------------------------------------------------------------------------------------- | ---------- |
| BotLimit                             | Maximum number of bots to add to the game.                                                      | 0-64       |
| DynamicBotAddThreshold               | Threshold to dynamically start adding bots. Number of players as percentage of maximum players. | 0.0-1.0    |
| bDemoteBotSquadLeadersIfHumanInSquad | Pick the most suitable human squad member and promote them if a squad has a bot squad leader.   | True/False |

See [ROMutator_Seed_Config.ini](Config/ROMutator_Seed_Config.ini) for
configuration example.

## Development TODOs

- Document bot configuration and console commands.

-  Server goes below dyn. bot threshold.
    -> Add bots to reach BotLimit.
