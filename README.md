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

## Admin Console Commands

These commands are runnable when logged in as the server admin or
from WebAdmin management console.

| Command                                           | Description                                             | Example                                     |
| ------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------- |
| `ROMutate SM_SetBotLimit BOT_LIMIT`               | Set bot limit to BOT_LIMIT.                             | `ROMutate SM_SetBotLimit 32`                |
| `ROMutate SM_SetDynamicBotAddThreshold THRESHOLD` | Set bot dynamic add threshold to THRESHOLD.             | `ROMutate SM_SetDynamicBotAddThreshold 0.5` |
| `ROMutate SM_SetDemoteBotSL [True/False]`         | Enable/disable demoting bot SLs when human is in squad. | `ROMutate SM_SetDemoteBotSL True`           |

## Usage Tips

- Set bot limit to 0 to kick all bots instantly.

## Development TODOs

- Document bot configuration and console commands.

-  Server goes below dyn. bot threshold.
    -> Add bots to reach BotLimit.
