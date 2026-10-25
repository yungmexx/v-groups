local groups = {}
local playerGroup = {}
local invitedPlayers = {}
local maxgroupsize = 4
local nextGroupId = 0
local nextInviteToken = 0

local function notify(target, message, success)
    if success then
        TriggerClientEvent('v-groups:client:SendNotification', target, message, 'success', 'bottom', '#141517', '#C1C2C5', 'check', 'green')
    else
        TriggerClientEvent('v-groups:client:SendNotification', target, message, 'error', 'bottom', '#141517', '#C1C2C5', 'x', 'red')
    end
end

local function getLeaderId(groupId)
    local group = groups[groupId]
    return group and group[1] and group[1].id
end

local function syncGroup(groupId)
    local group = groups[groupId]
    if not group or #group == 0 then return end
    local leaderId = group[1].id
    local formatted = {}
    for _, member in ipairs(group) do
        -- refresh names, the character may have loaded after the group was created
        member.name = GetCharName(member.id)
        table.insert(formatted, {
            id = member.id,
            name = member.name,
            leader = (member.id == leaderId)
        })
    end
    local leaderName = group[1].name
    for _, member in ipairs(group) do
        playerGroup[member.id] = groupId
        TriggerClientEvent(
            "group:client:updateGroup",
            member.id,
            formatted,
            leaderId,
            leaderName,
            maxgroupsize,
            groupId
        )
    end
end

-- Creates a new solo group with src as the host
local function createGroup(src)
    nextGroupId = nextGroupId + 1
    local groupId = nextGroupId
    groups[groupId] = {
        { id = src, name = GetCharName(src) }
    }
    playerGroup[src] = groupId
    return groupId
end

-- Returns the player's group, creating a solo one if they have none
local function ensureGroup(src)
    local groupId = playerGroup[src]
    if groupId and groups[groupId] then
        return groupId
    end
    playerGroup[src] = nil
    return createGroup(src)
end

-- Removes src from their group and syncs whoever is left
local function removeFromGroup(src)
    local groupId = playerGroup[src]
    playerGroup[src] = nil
    if not groupId then return end
    local group = groups[groupId]
    if not group then return end
    for i = #group, 1, -1 do
        if group[i].id == src then
            table.remove(group, i)
            break
        end
    end
    if #group == 0 then
        groups[groupId] = nil
    else
        syncGroup(groupId)
    end
end

-- Clears the pending invite sent to targetId and resets both players' invite buttons
local function clearInvite(targetId)
    local invite = invitedPlayers[targetId]
    if not invite then return end
    invitedPlayers[targetId] = nil
    TriggerClientEvent("group:client:inviteStatus", invite.from, targetId, nil)
    TriggerClientEvent("group:client:inviteStatus", targetId, invite.from, nil)
end

-- Cancels every invite sent by src (they left, were kicked or dropped)
local function clearInvitesFrom(src)
    for targetId, invite in pairs(invitedPlayers) do
        if invite.from == src then
            clearInvite(targetId)
            TriggerClientEvent("group:client:inviteCancelled", targetId)
        end
    end
end

-- Resets the invite button for playerId on every member of the group
local function resetStatusForGroup(groupId, playerId)
    local group = groups[groupId]
    if not group then return end
    for _, member in ipairs(group) do
        TriggerClientEvent("group:client:inviteStatus", member.id, playerId, nil)
    end
end

-- Takes src out of their group and puts them in a fresh solo group as host
local function moveToOwnGroup(src)
    local oldGroupId = playerGroup[src]
    clearInvitesFrom(src)
    removeFromGroup(src)
    resetStatusForGroup(oldGroupId, src)
    local groupId = createGroup(src)
    TriggerClientEvent("group:client:leftGroup", src)
    syncGroup(groupId)
    return oldGroupId
end


RegisterNetEvent("group:server:getNearbyName", function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    TriggerClientEvent(
        "group:client:receiveNearbyName",
        src,
        targetId,
        GetCharName(targetId)
    )
end)


RegisterNetEvent("group:server:invitePlayer", function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end
    if not IsPlayerLoaded(src) or not IsPlayerLoaded(targetId) then return end

    local fullName = GetCharName(src)
    local targetfullName = GetCharName(targetId)

    local groupId = ensureGroup(src)
    local group = groups[groupId]

    if playerGroup[targetId] == groupId then return end

    if #group >= maxgroupsize then
        notify(src, 'Your group is full', false)
        return
    end

    local existing = invitedPlayers[targetId]
    if existing then
        if existing.from ~= src then
            notify(src, targetfullName .. ' already has a pending invite', false)
        end
        return
    end

    nextInviteToken = nextInviteToken + 1
    local token = nextInviteToken
    invitedPlayers[targetId] = { from = src, groupId = groupId, token = token }

    notify(src, 'You have invited ' .. targetfullName, true)
    TriggerClientEvent(
        "group:client:receiveInvite",
        targetId,
        fullName,
        groupId,
        src
    )
    TriggerClientEvent("group:client:inviteStatus", src, targetId, "invited")
    TriggerClientEvent("group:client:inviteStatus", targetId, src, "invited")

    SetTimeout((Config.InviteTimeout or 30) * 1000, function()
        local invite = invitedPlayers[targetId]
        if invite and invite.token == token then
            clearInvite(targetId)
            TriggerClientEvent("group:client:inviteCancelled", targetId)
            notify(src, targetfullName .. ' did not respond to your invite', false)
        end
    end)
end)


RegisterNetEvent("group:server:requestGroup", function()
    local src = source
    syncGroup(ensureGroup(src))
end)


RegisterNetEvent("group:server:acceptInvite", function()
    local src = source
    local invite = invitedPlayers[src]
    if not invite then return end
    clearInvite(src)

    local groupId = invite.groupId
    local group = groups[groupId]

    -- the inviter must still be in the group they invited us to
    if not group or playerGroup[invite.from] ~= groupId then
        notify(src, 'That invite is no longer valid', false)
        return
    end

    if playerGroup[src] == groupId then return end

    if #group >= maxgroupsize then
        notify(src, 'That group is full', false)
        return
    end

    local fullName = GetCharName(src)

    local oldGroupId = playerGroup[src]
    clearInvitesFrom(src)
    removeFromGroup(src)
    resetStatusForGroup(oldGroupId, src)

    table.insert(group, {
        id = src,
        name = fullName
    })
    playerGroup[src] = groupId
    syncGroup(groupId)

    for _, member in ipairs(group) do
        if member.id ~= src then
            notify(member.id, fullName .. ' has joined the group', true)
        end
    end
    notify(src, 'You have joined the group', true)
end)


RegisterNetEvent("group:server:declineInvite", function()
    local src = source
    local invite = invitedPlayers[src]
    if not invite then return end
    clearInvite(src)
    notify(invite.from, GetCharName(src) .. ' declined invitation', false)
end)


RegisterNetEvent("group:server:kickPlayer", function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end

    local groupId = playerGroup[src]
    if not groupId or getLeaderId(groupId) ~= src then return end
    if playerGroup[targetId] ~= groupId then return end

    moveToOwnGroup(targetId)

    local fullName = GetCharName(src)
    local targetfullName = GetCharName(targetId)

    notify(targetId, fullName .. ' has kicked you from the group', false)
    notify(src, 'You have kicked ' .. targetfullName .. ' from the group', false)
end)


RegisterNetEvent("group:server:leaveGroup", function()
    local src = source
    local groupId = playerGroup[src]
    local group = groupId and groups[groupId]
    -- a solo host is already in their own group, nothing to leave
    if not group or #group <= 1 then return end

    moveToOwnGroup(src)

    local targetfullName = GetCharName(src)
    for _, member in ipairs(group) do
        notify(member.id, targetfullName .. ' has left the group', false)
    end
    notify(src, 'You have left the group', false)
end)


AddEventHandler('playerDropped', function()
    local src = source

    clearInvite(src)
    clearInvitesFrom(src)

    local groupId = playerGroup[src]
    removeFromGroup(src)
    resetStatusForGroup(groupId, src)
end)


-- Character logout (multicharacter): the next character starts in a fresh group
local function onCharacterUnload(src)
    src = tonumber(src)
    if not src or not playerGroup[src] then return end
    if invitedPlayers[src] then
        clearInvite(src)
        TriggerClientEvent("group:client:inviteCancelled", src)
    end
    moveToOwnGroup(src)
end

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    onCharacterUnload(src or source)
end)

AddEventHandler('esx:playerLogout', function(src)
    onCharacterUnload(src or source)
end)


-- Put everyone already online into their own group when the resource starts
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do
        syncGroup(ensureGroup(tonumber(id)))
    end
end)



-- Get all groups
exports('GetGroups', function()
    return groups
end)

-- Get a player's group id
exports('GetPlayerGroup', function(playerId)
    return playerGroup[playerId]
end)

-- Get full group table
exports('GetGroupMembers', function(groupId)
    if not groupId then
        return {}
    end

    return groups[groupId] or {}
end)

-- Get leader id
exports('GetGroupLeader', function(groupId)
    return getLeaderId(groupId)
end)

-- Get leader name
exports('GetGroupLeaderName', function(groupId)
    local leaderId = getLeaderId(groupId)

    if not leaderId then
        return nil
    end

    return GetCharName(leaderId)
end)

-- Check if player is in group
exports('IsPlayerInGroup', function(playerId)
    return playerGroup[playerId] ~= nil
end)

-- Check if player is group leader
exports('IsGroupLeader', function(playerId)
    local groupId = playerGroup[playerId]

    if not groupId then
        return false
    end

    return getLeaderId(groupId) == playerId
end)

-- Get group size
exports('GetGroupSize', function(groupId)
    local group = groups[groupId]

    if not group then
        return 0
    end

    return #group
end)

-- Check if group is full
exports('IsGroupFull', function(groupId, maxSize)
    maxSize = maxSize or maxgroupsize

    local group = groups[groupId]

    if not group then
        return false
    end

    return #group >= maxSize
end)

-- Get invited players
exports('GetInvitedPlayers', function()
    return invitedPlayers
end)

-- Check if player is invited
exports('IsPlayerInvited', function(playerId)
    return invitedPlayers[playerId] ~= nil
end)

-- Get formatted group data
exports('GetFormattedGroup', function(groupId)
    local group = groups[groupId]

    if not group then
        return {}
    end

    local formatted = {}

    local leaderId = group[1] and group[1].id

    for _, member in ipairs(group) do
        table.insert(formatted, {
            id = member.id,
            name = member.name,
            leader = member.id == leaderId
        })
    end

    return formatted
end)
