/**
 * Copyright (c) 2024 Tuomo Kriikkula
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

// Seeding utilities for dedicated servers.
class SeedMutator extends ROMutator
    config(Mutator_Seed);

const SEEDMUTATOR_CONFIG_VERSION = 1;
const SEEDMUTATOR_DEFAULT_BOT_LIMIT = 32;
const SEEDMUTATOR_DEFAULT_BOT_ADD_THRESH = 0.5;

// Stored in a separate object to be able to ship
// read-only mutator config file with workshop while
// keeping the per-server config adjustable.
var SeedMutatorConfig Config;

function PreBeginPlay()
{
    super.PreBeginPlay();

    Config = new (self) class'SeedMutatorConfig';

    if (Config.ConfigVersion != SEEDMUTATOR_CONFIG_VERSION)
    {
        `smlog("current ConfigVersion is not up to date"
            @ "(" $ SEEDMUTATOR_CONFIG_VERSION $ ")"
            @ "performing first time initialization"
        );

        Config.ConfigVersion = SEEDMUTATOR_CONFIG_VERSION;

        if (Config.BotLimit <= 0 || Config.BotLimit > 64)
        {
            Config.BotLimit = SEEDMUTATOR_DEFAULT_BOT_LIMIT;
        }
        if (Config.DynamicBotAddThreshold <= 0.0 || Config.DynamicBotAddThreshold > 1.0)
        {
            Config.DynamicBotAddThreshold = SEEDMUTATOR_DEFAULT_BOT_ADD_THRESH;
        }

        Config.SaveConfig();
    }

    SetTimer(1.0, True, NameOf(CheckStatus));

    `smlog("mutator initialized,"
        @ "BotLimit=" $ Config.BotLimit
        @ "DynamicBotAddThreshold=" $ Config.DynamicBotAddThreshold
    );
}

function ROMutate(string MutateString, PlayerController Sender, out string ResultMsg)
{
    local array<string> Args;
    local string Command;
    local bool bSuccess;

    if (!WorldInfo.Game.AccessControl.IsAdmin(Sender))
    {
        `smlog("Warning!"
            @ Sender
            @ Sender.PlayerReplicationInfo.PlayerName
            @ ROPlayerReplicationInfo(Sender.PlayerReplicationInfo).SteamId64
            @ Sender.GetPlayerNetworkAddress()
            @ "attempted to execute command"
            @ "'" $ MutateString $ "'"
            @ "but is not an admin, request denied."
        );

        ResultMsg = "invalid";
        return;
    }

    Args = SplitString(MutateString);
    Command = Locs(Args[0]);

    switch (Command)
    {
        case "sm_help":
            // TODO: print/log help.
            break;
        case "sm_setbotlimit":
            bSuccess = HandleSetBotLimit(Args);
            break;
        case "sm_setdynamicbotaddthreshold":
            bSuccess = HandleSetDynamicBotAddThreshold(Args);
            break;
        default:
            `smlog("command '" $ Command $ "' not recognized by SeedMutator");
            bSuccess = False;
            break;
    }

    `smlog(Sender
        @ Sender.PlayerReplicationInfo.PlayerName
        @ ROPlayerReplicationInfo(Sender.PlayerReplicationInfo).SteamId64
        @ Sender.GetPlayerNetworkAddress()
        @ "executed command '" $ MutateString $ "'"
        @ "bSuccess=" $ bSuccess
    );

    super.ROMutate(MutateString, Sender, ResultMsg);
}

function bool HandleSetBotLimit(const out array<string> Args)
{
    local int NewBotLimit;

    NewBotLimit = int(Args[1]);
    if (NewBotLimit >= 0 && NewBotLimit <= 64)
    {
        Config.BotLimit = NewBotLimit;
        Config.SaveConfig();
        `smlog("updated BotLimit to" @ Config.BotLimit);
        return True;
    }

    return False;
}

function bool HandleSetDynamicBotAddThreshold(const out array<string> Args)
{
    local float NewDynThresh;

    NewDynThresh = float(Args[1]);
    if (NewDynThresh >= 0.0 && NewDynThresh <= 1.0)
    {
        Config.DynamicBotAddThreshold = NewDynThresh;
        Config.SaveConfig();
        `smlog("updated DynamicBotAddThreshold to" @ Config.DynamicBotAddThreshold);
        return True;
    }

    return False;
}

// TODO: refactor into more functions?
function CheckStatus()
{
    local float PlayerRatio;

    if (Config.BotLimit > 0 && Config.DynamicBotAddThreshold > 0.0)
    {
        PlayerRatio = WorldInfo.Game.GetNumPlayers() / WorldInfo.Game.MaxPlayers;

        if (PlayerRatio <= Config.DynamicBotAddThreshold)
        {
            // Add bots to the game.
        }
    }
}

// TODO: yadda yadda.
function AddBots(int Num, optional int NewTeam = -1, optional bool bNoForceAdd)
{
    local ROAIController ROBot;
    local byte ChosenTeam;
    local byte SuggestedTeam;
    local ROPlayerReplicationInfo ROPRI;
    local ROGameInfo ROGI;

    if (WorldInfo.Game.bLevelChange)
    {
        return;
    }

    ROGI = ROGameInfo(WorldInfo.Game);

    while (Num > 0 && ROGI.NumBots + ROGI.NumPlayers < ROGI.MaxPlayers)
    {
        // Create a new Controller for this Bot.
        ROBot = Spawn(ROGI.AIControllerClass);

        // Assign the bot a Player ID.
        ROBot.PlayerReplicationInfo.PlayerID = ROGI.CurrentID++;

        // Suggest a team to put the AI on
        if (ROGI.bBalanceTeams || NewTeam == -1)
        {
            if (ROGI.GameReplicationInfo.Teams[`AXIS_TEAM_INDEX].Size - ROGI.GameReplicationInfo.Teams[`ALLIES_TEAM_INDEX].Size <= 0
                && ROGI.BotCapableNorthernRolesAvailable())
            {
                SuggestedTeam = `AXIS_TEAM_INDEX;
            }
            else if (ROGI.BotCapableSouthernRolesAvailable())
            {
                SuggestedTeam = `ALLIES_TEAM_INDEX;
            }
            // If there are no roles available on either team, don't allow this to go any further.
            else
            {
                ROBot.Destroy();
                return;
            }
        }
        else if (ROGI.BotCapableNorthernRolesAvailable() || ROGI.BotCapableSouthernRolesAvailable())
        {
            SuggestedTeam = NewTeam;
        }
        else
        {
            ROBot.Destroy();
            return;
        }

        // Put the new Bot on the Team that needs it.
        ChosenTeam = ROGI.PickTeam(SuggestedTeam, ROBot);
        // Set the bot name based on team.
        ROGI.ChangeName(ROBot, ROGI.GetDefaultBotName(
            ROBot, ChosenTeam, ROTeamInfo(ROGI.GameReplicationInfo.Teams[ChosenTeam]).NumBots + 1), false);

        ROGI.JoinTeam(ROBot, ChosenTeam);

        ROBot.SetTeam(ROBot.PlayerReplicationInfo.Team.TeamIndex);

        // Have the bot choose its role.
        if (!ROBot.ChooseRole())
        {
            ROBot.Destroy();
            continue;
        }

        ROBot.ChooseSquad();

        // GRIP  BEGIN
        // Remove. Debugging purpose only.
        ROPRI = ROPlayerReplicationInfo(ROBot.PlayerReplicationInfo);
        if (ROPRI.RoleInfo.bIsTankCommander)
        {
            ROGI.ChangeName(ROBot, ROPRI.GetHumanReadableName() $" (TankAI)", false);
        }
        // GRIP END

        if (ROTeamInfo(ROBot.PlayerReplicationInfo.Team) != none
            && ROTeamInfo(ROBot.PlayerReplicationInfo.Team).ReinforcementsRemaining > 0)
        {
            // Spawn a Pawn for the new Bot Controller.
            ROGI.RestartPlayer(ROBot);
        }

        if (ROGI.bInRoundStartScreen)
        {
            ROBot.AISuspended();
        }

        // Note that we've added another Bot.
        if (!bNoForceAdd)
        {
            ROGI.DesiredPlayerCount++;
        }
        ++ROGI.NumBots;
        --Num;
        ROGI.UpdateGameSettingsCounts();
    }
}

DefaultProperties
{
}
