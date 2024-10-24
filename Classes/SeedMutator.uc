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

const SEEDMUTATOR_CONFIG_VERSION = 3;
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
    if (Config == None)
    {
        `smlog("FATAL ERROR! FAILED TO INITIALIZE CONFIGURATION!");
    }

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

        // TODO: force this on for now. Maybe remove this check in some future version?
        Config.bDemoteBotSquadLeadersIfHumanInSquad = True;

        Config.SaveConfig();
    }

    // Enable checks after a delay. TODO: adjust this delay?
    SetTimer(5.0, False, NameOf(EnableCheckStatusTimer));

    // Perform various checks periodically.
    SetTimer(3.0, True, NameOf(CheckBots));

    `smlog("mutator initialized,"
        @ "BotLimit=" $ Config.BotLimit
        @ "DynamicBotAddThreshold=" $ Config.DynamicBotAddThreshold
        @ "bDemoteBotSquadLeadersIfHumanInSquad=" $ Config.bDemoteBotSquadLeadersIfHumanInSquad
    );
}

function DemoteBotSquadLeaders()
{
    local AIController AIC;
    local ROPlayerReplicationInfo ROPRI;
    local bool bSquadHasHuman;
    local byte NewSquadLeaderIndex;
    local int i;

    ForEach WorldInfo.AllControllers(class'AIController', AIC)
    {
        ROPRI = ROPlayerReplicationInfo(AIC.PlayerReplicationInfo);
        if (ROPRI == None || !ROPRI.bIsSquadLeader)
        {
            continue;
        }

        bSquadHasHuman = False;
        for (i = 0; i < `MAX_ROLES_PER_SQUAD; ++i)
        {
            if (ROPlayerController(ROPRI.Squad.SquadMembers[i].Owner) != None)
            {
                bSquadHasHuman = True;
                `smlog(
                    "squad" @ ROPRI.Squad $ ", Title=" $ ROPRI.Squad.Title $ ", TeamIndex=" $ ROPRI.Squad.Team.TeamIndex
                    @ "has a BOT squad leader while the squad has human players");
                break;
            }
        }

        if (bSquadHasHuman)
        {
            NewSquadLeaderIndex = FindNewSquadLeader(ROPRI.Squad);
            if (NewSquadLeaderIndex == 255)
            {
                // TODO: log error here?
                continue;
            }

            if (NewSquadLeaderIndex < `MAX_ROLES_PER_SQUAD)
            {
                `smlog("promoting role at index" @ NewSquadLeaderIndex @ "to squad leader");
                ROPRI.Squad.PromoteToSquadLeader(NewSquadLeaderIndex);
                ROPRI.Squad.AlertSpawnChange(True);
            }
        }
    }
}

// Copied from ROSquadInfo::FindNewSquadLeader with additional check to prevent
// offering bots as the new squad leader.
function byte FindNewSquadLeader(ROSquadInfo Squad)
{
    local array<byte> CandidateRoleIndices;
    local int i, LowestTier;

    LowestTier = 4;

    // First find the lowest class tier available in this squad.
    for (i = 1; i < `MAX_ROLES_PER_SQUAD; ++i)
    {
        if (PlayerController(Squad.SquadMembers[i].Owner) != None)
        {
            if (Squad.GetRole(i).ClassTier < LowestTier)
            {
                LowestTier = Squad.GetRole(i).ClassTier;
            }
        }
    }

    // Now store the role indices of all classes in the squad with that same tier
    // who are highly ranked enough to be eligible for SL.
    for (i = 1; i < `MAX_ROLES_PER_SQUAD; ++i)
    {
        if (PlayerController(Squad.SquadMembers[i].Owner) != none
            && ROPlayerReplicationInfo(Squad.SquadMembers[i].Owner.PlayerReplicationInfo) != none
            && ROPlayerReplicationInfo(Squad.SquadMembers[i].Owner.PlayerReplicationInfo).HonorLevel >= `MIN_LEVEL_SQUADLEADER
            && !ROPlayerReplicationInfo(Squad.SquadMembers[i].Owner.PlayerReplicationInfo).bIsDev
        )
        {
            if (Squad.GetRole(i).ClassTier == LowestTier)
            {
                CandidateRoleIndices.AddItem(i);
            }
        }
    }

    // If there is no-one suitable, check again but this time throw out the rank requirement (we cannot have _no_ SL).
    if (CandidateRoleIndices.length <= 0)
    {
        for (i = 1; i < `MAX_ROLES_PER_SQUAD; ++i)
        {
            if (PlayerController(Squad.SquadMembers[i].Owner) != none)
            {
                if (Squad.GetRole(i).ClassTier == LowestTier)
                {
                    CandidateRoleIndices.AddItem(i);
                }
            }
        }
    }

    // And lastly pick a random player from the condensed list.
    if (CandidateRoleIndices.length > 0)
    {
        return CandidateRoleIndices[Rand(CandidateRoleIndices.length)];
    }

    return 255;
}

// - Demote bots that are taking up squad leader slots in a squad with human players in it.
// TODO: check if we can do something about https://github.com/tuokri/SeedMutator/issues/1
function CheckBots()
{
    if (Config.bDemoteBotSquadLeadersIfHumanInSquad)
    {
        DemoteBotSquadLeaders();
    }
}

function EnableCheckStatusTimer()
{
    SetTimer(1.0, True, NameOf(CheckStatus));
}

function ModifyPreLogin(string Options, string Address, out string ErrorMessage)
{
    // If we're nearing MaxPlayers, kick out a bot here?

    super.ModifyPreLogin(Options, Address, ErrorMessage);
}

function ROMutate(string MutateString, PlayerController Sender, out string ResultMsg)
{
    local array<string> Args;
    local string Command;
    local bool bSuccess;

    // TODO: just use ~=?
    if (!(Mid(Locs(MutateString), 0, 3) == "sm_"))
    {
        // `smdebug("ignoring command:" @ MutateString);
        super.ROMutate(MutateString, Sender, ResultMsg);
        return;
    }

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

    Args = SplitString(MutateString, " ", True);
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
        case "sm_setdemotebotsl":
            bSuccess = HandleSetDemoteBotSquadLeaders(Args);
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

    if (Args.Length < 1)
    {
        return False;
    }

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

    if (Args.Length < 1)
    {
        return False;
    }

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

function bool HandleSetDemoteBotSquadLeaders(const out array<string> Args)
{
    local bool bShouldDemoteBotSLs;
    local string BoolArg;

    if (Args.Length < 1)
    {
        return False;
    }

    BoolArg = Locs(Args[1]);
    if (BoolArg == "false" || BoolArg == "true" || BoolArg == "0" || BoolArg == "1")
    {
        bShouldDemoteBotSLs = bool(BoolArg);
        Config.bDemoteBotSquadLeadersIfHumanInSquad = bShouldDemoteBotSLs;
        Config.SaveConfig();
        `smlog("updated bDemoteBotSquadLeadersIfHumanInSquad to" @ Config.bDemoteBotSquadLeadersIfHumanInSquad);
        return True;
    }

    return False;
}

// TODO: is this stupid? Just use the built-in DesiredPlayers functionality.
// TODO: refactor into more functions?
function CheckStatus()
{
    local float PlayerRatio;
    local AIController Bot;
    local int BotDiff;
    local ROGameInfo ROGI;
    local bool bServerIsFull;

    BotDiff = Config.BotLimit - WorldInfo.Game.NumBots;
    PlayerRatio = WorldInfo.Game.GetNumPlayers() / WorldInfo.Game.MaxPlayers;

    // `log("DesiredPlayerCount :" @ ROGameInfo(WorldInfo.Game).DesiredPlayerCount);
    // `log("NumBots            :" @ WorldInfo.Game.NumBots);
    // `log("NumPlayers         :" @ WorldInfo.Game.GetNumPlayers());
    // `log("PlayerRatio        :" @ PlayerRatio);
    // `log("BotDiff            :" @ BotDiff);

    if (Config.BotLimit > 0 && Config.DynamicBotAddThreshold > 0.0)
    {
        bServerIsFull = (WorldInfo.Game.GetNumPlayers() + WorldInfo.Game.NumBots) >= WorldInfo.Game.MaxPlayers;
        if (!bServerIsFull && (PlayerRatio <= Config.DynamicBotAddThreshold && BotDiff > 0))
        {
            AddBots(BotDiff);
        }
    }
//     TODO: if we're above thresh, start kicking bots here?
//     else if ()
//     {
//
//     }
    else if (Config.BotLimit == 0 && WorldInfo.Game.NumBots > 0)
    {
        // TODO: check ROGameInfo::KillBots.

        `smlog("BotLimit set to 0, force kicking all bots...");

        ROGI = ROGameInfo(WorldInfo.Game);

        ForEach WorldInfo.AllControllers(class'AIController', Bot)
        {
            `smlog("kicking" @ Bot @ Bot.PlayerReplicationInfo.PlayerName);

            if (Bot.Pawn != None)
            {
                Bot.Pawn.KilledBy(Bot.Pawn);
            }

            Bot.Destroy();

            --ROGI.DesiredPlayerCount;
            // --ROGI.NumBots;
        }
    }

    UpdateGameSettingsCounts(ROGI, True);
}

function AddBots(int Num, optional int NewTeam = -1)
{
    local ROAIController ROBot;
    local byte ChosenTeam;
    local byte SuggestedTeam;
    local ROGameInfo ROGI;
    local string BotName;

    if (WorldInfo.Game.bLevelChange)
    {
        return;
    }

    ROGI = ROGameInfo(WorldInfo.Game);

    `smlog("attempting to add" @ Num @ "bots...");

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
        BotName = ROGI.GetDefaultBotName(ROBot,
            ChosenTeam, ROTeamInfo(ROGI.GameReplicationInfo.Teams[ChosenTeam]).NumBots + 1);
        // Make sure bot names start with "BOT " prefix.
        if (!(InStr(BotName, "BOT", False, True) == 0))
        {
            BotName = "BOT" @ BotName;
        }
        ROGI.ChangeName(ROBot, BotName, false);

        ROGI.JoinTeam(ROBot, ChosenTeam);

        ROBot.SetTeam(ROBot.PlayerReplicationInfo.Team.TeamIndex);

        // Have the bot choose its role.
        if (!ROBot.ChooseRole())
        {
            ROBot.Destroy();
            continue;
        }

        ROBot.ChooseSquad();

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

        ++ROGI.DesiredPlayerCount;
        ++ROGI.NumBots;
        --Num;
        `smlog("added bot" @ ROBot @ ROBot.PlayerReplicationInfo.PlayerName);

        // ROGI.UpdateGameSettingsCounts();
        // Custom handler for this in mutator to also se NumBots.
        UpdateGameSettingsCounts(ROGI);
    }
}

function UpdateGameSettingsCounts(ROGameInfo ROGI, optional bool bSendToBackend)
{
    local OnlineGameSettings GameSettings;

    if (ROGI.GameInterface != None)
    {
        GameSettings = ROGI.GameInterface.GetGameSettings(
            ROGI.PlayerReplicationInfoClass.default.SessionName);

        if (GameSettings != None)
        {
            // Make sure that we don't exceed our max allowing player counts for this game type!
            GameSettings.NumPublicConnections = Clamp(ROGI.MaxPlayers, 0, ROGI.MaxPlayersAllowed);
            GameSettings.NumPrivateConnections = Clamp(
                GameSettings.NumPrivateConnections, 0, ROGI.MaxPlayers - GameSettings.NumPublicConnections);

            // Update the number of open slots available.
            GameSettings.NumOpenPublicConnections = Clamp(
                GameSettings.NumPublicConnections - ROGI.GetNumPlayers(), 0, GameSettings.NumPublicConnections);

            GameSettings.NumBots = ROGI.NumBots;

            ROGI.OnlineSub.GameInterface.UpdateOnlineGame(
                ROGI.PlayerReplicationInfoClass.default.SessionName, GameSettings, bSendToBackend);
        }
    }
}

DefaultProperties
{
}
