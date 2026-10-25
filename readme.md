# v-groups

A lightweight group script. Players can invite anyone standing nearby into a group, see who's in it, hand off leadership automatically, and kick or leave whenever they want — all through a clean NUI panel instead of chat commands. It's built to be dropped into other jobs (like a garbage or delivery job) that lets players work as a team.

<img width="404" height="453" alt="f9c927281428cc00304c37449f75451e5c09e50d" src="https://github.com/user-attachments/assets/7f499572-46af-4b4c-87ea-9b76a5a57f5f" />


## Requirements
- NONE


## Installation

1. Drop the `v-groups` folder into your `[qb]` resources category.
2. Add `ensure v-groups` to your `server.cfg`, after `qb-core`.
3. Open `config/config.lua` and set `Config.Notification` to match whatever notification system your server uses (`'qb'`, `'ox'`, or `'gta'`).
4. Restart the resource (or your server) and you're good to go.

## Using it in-game

Run `/groups` (bindable to a key like any other command) to open the panel. From there:

- **Nearby Players** lists everyone within about 10 meters. Hit invite next to a name to send them a request.
- The invited player gets a popup with Accept/Decline. Accepting drops them into your group; declining just resets things quietly.
- **Your Group** shows everyone currently in your party, who the leader is, and how full the group is (`x / 4`).
- If you're the leader, you'll see a Kick button next to each member. Everyone else sees a Leave button on themselves.
- Shift toggles your mouse cursor without closing the panel. Escape or the ✕ closes it outright.

## Config

`config/config.lua`:

```lua
Config.Framework = 'auto_detect' -- 'auto_detect', 'qb', 'qbox', 'esx', 'standalone'
Config.Notification = 'gta'      -- 'qb', 'ox' (needs ox_lib), or 'gta'
Config.InviteTimeout = 30        -- seconds before an unanswered invite expires
```

Every player is always in a group: when the resource starts, when they spawn or load a character, they're placed in their own group as host. Accepting an invite moves them into the inviter's group; leaving or being kicked puts them back in a fresh group of their own.

The group size cap (4) isn't a config option on purpose — it's a single constant on the server (`maxgroupsize` in `server/main.lua`) so a modified client can never talk it into accepting a bigger group. If you genuinely need a different cap, change that one line.

## Exports

### Server (`v-groups`)

| Export | Returns |
|---|---|
| `GetGroups()` | The full internal groups table |
| `GetPlayerGroup(playerId)` | The group id a player belongs to (or nil) |
| `GetGroupMembers(groupId)` | Raw member list for a group |
| `GetGroupLeader(groupId)` | Server id of the group's leader |
| `GetGroupLeaderName(groupId)` | The leader's full character name |
| `IsPlayerInGroup(playerId)` | `true`/`false` |
| `IsGroupLeader(playerId)` | `true`/`false` |
| `GetGroupSize(groupId)` | Member count |
| `IsGroupFull(groupId, maxSize)` | `true`/`false` (defaults to 4) |
| `GetInvitedPlayers()` | Table of players with a pending invite |
| `IsPlayerInvited(playerId)` | `true`/`false` |
| `GetFormattedGroup(groupId)` | Member list formatted for display, with `leader` flags |

### Client (`v-groups`)

| Export | Returns |
|---|---|
| `GetGroupMembers()` | Your local copy of the group member list |
| `GetGroupLeader()` | Server id of your group's leader |
| `GetGroupLeaderName()` | Your leader's name |
| `GetGroupID()` | The unique id of your current group |
| `IsGroupLeader()` | `true` if you're the leader |
| `IsPlayerInGroup(playerId)` | `true` if that player is in your group |
| `GetGroupSize()` | Your group's member count |
| `GetNearbyGroupPlayers()` | List of nearby, invitable players |
| `GetPlayerStatuses()` | Invite status per nearby player |
| `IsGroupUiOpen()` | `true`/`false` |
| `ToggleGroupUi(state)` | Opens/closes the panel; pass `true`/`false`, or nothing to toggle |
| `OpenGroup()` | Opens the panel (does nothing if it's already open) — handy for target menus |
| `RefreshNearbyPlayers()` | Forces an immediate re-scan of nearby players |
| `GetCurrentGroupData()` | `{ members, leaderId, leaderName }` in one call |

A typical integration — say, a job checking if the player is grouped up before paying out a teamwork bonus — looks like:

```lua
local inGroup = exports['v-groups']:IsPlayerInGroup(GetPlayerServerId(PlayerId()))
local groupId = exports['v-groups']:GetGroupID()
```

## A note on trust

Every server event validates who's actually allowed to do what — you can't join a group you weren't invited to, you can't kick someone unless you're the leader, and the group cap can't be bypassed from the client. If you're extending this resource, keep that pattern: never trust an id or state coming from the client without checking it against what the server already knows.
