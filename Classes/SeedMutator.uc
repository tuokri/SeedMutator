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

// Maximum number of bots to add to the game.
var(SeedMutator) config int BotLimit;
// Threshold to dynamically start adding bots.
// Number of players as percentage of maximum players.
var(SeedMutator) config float DynamicBotAddThreshold;
// Config version. Updated in case of backwards-incompatible
// changes in mutator code.
var(SeedMutator) config int ConfigVersion;

function PreBeginPlay()
{
    super.PreBeginPlay();

    if (ConfigVersion != SEEDMUTATOR_CONFIG_VERSION)
    {
        `smlog("current ConfigVersion is not up to date"
            @ "(" $ SEEDMUTATOR_CONFIG_VERSION $ ")"
            @ "performing first time initialization"
        );

        if (BotLimit <= 0 || BotLimit > 64)
        {
            BotLimit = SEEDMUTATOR_DEFAULT_BOT_LIMIT;
        }
        if (DynamicBotAddThreshold <= 0.0 || DynamicBotAddThreshold > 1.0)
        {
            DynamicBotAddThreshold = SEEDMUTATOR_DEFAULT_BOT_ADD_THRESH;
        }

        SaveConfig();
    }

    `smlog("mutator initialized,"
        @ "BotLimit=" $ BotLimit
        @ "DynamicBotAddThreshold=" $ DynamicBotAddThreshold
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
        BotLimit = NewBotLimit;
        SaveConfig();
        `smlog("updated BotLimit to" @ BotLimit);
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
        DynamicBotAddThreshold = NewDynThresh;
        SaveConfig();
        `smlog("updated DynamicBotAddThreshold to" @ DynamicBotAddThreshold);
        return True;
    }

    return False;
}

DefaultProperties
{
}
