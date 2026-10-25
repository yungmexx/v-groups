local isUiOpen = false
local nearbyPlayers = {}
local nearbyCache = {}
local activeIds = {}
local groupMembers = {}
local playerNames = {}
local pendingNames = {}
local currentLeaderId = nil


local currentLeaderName = nil
local currentMaxSize = 4
local playerStatus = {}
local currentInviterId = nil
local currentInviteGroup = nil
local currentGroupId = nil
local cursorActive = true



--  ███████╗██╗░░░██╗███╗░░██╗░█████╗░████████╗██╗░█████╗░███╗░░██╗
--  ██╔════╝██║░░░██║████╗░██║██╔══██╗╚══██╔══╝██║██╔══██╗████╗░██║
--  █████╗░░██║░░░██║██╔██╗██║██║░░╚═╝░░░██║░░░██║██║░░██║██╔██╗██║
--  ██╔══╝░░██║░░░██║██║╚████║██║░░██╗░░░██║░░░██║██║░░██║██║╚████║
--  ██║░░░░░╚██████╔╝██║░╚███║╚█████╔╝░░░██║░░░██║╚█████╔╝██║░╚███║
--  ╚═╝░░░░░░╚═════╝░╚═╝░░╚══╝░╚════╝░░░░╚═╝░░░╚═╝░╚════╝░╚═╝░░╚══╝

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextEntry("STRING")
        AddTextComponentString(text)
        SetTextScale(0.55, 0.55)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextOutline()
        SetTextCentre(true)
        DrawText(_x, _y)
    end
end

local function isInGroup(playerId)
    for _, member in pairs(groupMembers) do
        if member.id == playerId then
            return true
        end
    end
    return false
end


local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function updateNearbyPlayers()
    clearTable(nearbyPlayers)
    clearTable(nearbyCache)
    clearTable(activeIds)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    for _, player in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)
        activeIds[serverId] = true
        local targetPed = GetPlayerPed(player)
        if targetPed ~= myPed then
            local coords = GetEntityCoords(targetPed)
            local dx, dy, dz = coords.x - myCoords.x, coords.y - myCoords.y, coords.z - myCoords.z
            local distSq = dx * dx + dy * dy + dz * dz
            if distSq <= 100.0 then
                nearbyCache[#nearbyCache + 1] = { ped = targetPed, id = serverId }
                if not isInGroup(serverId) then
                    local inviteState = playerStatus[serverId] or "invite"
                    if not playerNames[serverId] and not pendingNames[serverId] then
                        pendingNames[serverId] = true
                        TriggerServerEvent("group:server:getNearbyName", serverId)
                    end
                    local name = playerNames[serverId] or GetPlayerName(player) or ("ID: " .. serverId)
                    local data = {
                        id = serverId,
                        name = name or "Unknown",
                        distance = math.floor(math.sqrt(distSq) * 10) / 10,
                        status = inviteState
                    }
                    table.insert(nearbyPlayers, data)
                end
            end
        end
    end

    for id in pairs(playerNames) do
        if not activeIds[id] then playerNames[id] = nil end
    end
    for id in pairs(pendingNames) do
        if not activeIds[id] then pendingNames[id] = nil end
    end
    for id in pairs(playerStatus) do
        if not activeIds[id] then playerStatus[id] = nil end
    end

    SendNUIMessage({
        action = "setNearbyPlayers",
        players = nearbyPlayers
    })
end

local function setUiOpen(state)
    isUiOpen = state
    cursorActive = true
    SetNuiFocus(isUiOpen, isUiOpen)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = "toggle",
        state = isUiOpen
    })
    if isUiOpen then
        SendNUIMessage({
            action = "setMyId",
            id = GetPlayerServerId(PlayerId())
        })
        TriggerServerEvent("group:server:requestGroup")
        updateNearbyPlayers()
    else
        if currentInviterId then
            -- keep the cursor for a pending invite popup
            SetNuiFocus(true, true)
        end
        collectgarbage("collect")
    end
end

local function toggleGroup()
    setUiOpen(not isUiOpen)
end


local function resetInvites()
    playerStatus = {}
end

-- Called when we leave/are kicked; the server sends our new solo group right after
local function resetGroupState()
    resetInvites()
    groupMembers = {}
    currentLeaderId = nil
    currentLeaderName = nil
    currentGroupId = nil
end

-- Closes the invite popup and releases focus if the panel is not open
local function closeInvitePopup()
    currentInviteGroup = nil
    currentInviterId = nil
    SendNUIMessage({
        action = "hideInvite"
    })
    if not isUiOpen then
        SetNuiFocus(false, false)
    end
end

local function requestGroup()
    TriggerServerEvent("group:server:requestGroup")
end



--  ███╗░░██╗██╗░░░██╗██╗  ░█████╗░░█████╗░██╗░░░░░██╗░░░░░██████╗░░█████╗░░█████╗░██╗░░██╗
--  ████╗░██║██║░░░██║██║  ██╔══██╗██╔══██╗██║░░░░░██║░░░░░██╔══██╗██╔══██╗██╔══██╗██║░██╔╝
--  ██╔██╗██║██║░░░██║██║  ██║░░╚═╝███████║██║░░░░░██║░░░░░██████╦╝███████║██║░░╚═╝█████═╝░
--  ██║╚████║██║░░░██║██║  ██║░░██╗██╔══██║██║░░░░░██║░░░░░██╔══██╗██╔══██║██║░░██╗██╔═██╗░
--  ██║░╚███║╚██████╔╝██║  ╚█████╔╝██║░░██║███████╗███████╗██████╦╝██║░░██║╚█████╔╝██║░╚██╗
--  ╚═╝░░╚══╝░╚═════╝░╚═╝  ░╚════╝░╚═╝░░╚═╝╚══════╝╚══════╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝

RegisterNUICallback("close", function(_, cb)
    if isUiOpen then
        setUiOpen(false)
    elseif not currentInviterId then
        SetNuiFocus(false, false)
    end
    cb("ok")
end)

-- Shift: hide the cursor and give movement back without closing the panel
RegisterNUICallback("toggleMouse", function(_, cb)
    if isUiOpen then
        cursorActive = not cursorActive
        SetNuiFocus(true, cursorActive)
        SetNuiFocusKeepInput(not cursorActive)
    end
    cb("ok")
end)

RegisterNUICallback("invitePlayer", function(data, cb)
    local playerId = tonumber(data.playerId)

    if playerId then
        TriggerServerEvent(
            "group:server:invitePlayer",
            playerId
        )
    end

    cb("ok")
end)


RegisterNUICallback("acceptInvite", function(data, cb)
    if currentInviterId then
        TriggerServerEvent("group:server:acceptInvite")
    end

    closeInvitePopup()
    cb("ok")
end)


RegisterNUICallback("declineInvite", function(data, cb)
    if currentInviterId then
        TriggerServerEvent("group:server:declineInvite")
        TriggerEvent('v-groups:client:SendNotification', 'You have declined the invite', 'error', 'bottom', '#141517', '#C1C2C5', 'x', 'red')
    end

    closeInvitePopup()
    cb("ok")
end)

RegisterNUICallback("leaveGroup", function(data, cb)
    TriggerServerEvent("group:server:leaveGroup")
    cb("ok")
end)

RegisterNUICallback("kickPlayer", function(data, cb)
    local playerId = tonumber(data.playerId)
    if playerId then
        TriggerServerEvent("group:server:kickPlayer", playerId)
    end
    cb("ok")
end)


--  ███╗░░██╗███████╗████████╗  ███████╗██╗░░░██╗███████╗███╗░░██╗████████╗
--  ████╗░██║██╔════╝╚══██╔══╝  ██╔════╝██║░░░██║██╔════╝████╗░██║╚══██╔══╝
--  ██╔██╗██║█████╗░░░░░██║░░░  █████╗░░╚██╗░██╔╝█████╗░░██╔██╗██║░░░██║░░░
--  ██║╚████║██╔══╝░░░░░██║░░░  ██╔══╝░░░╚████╔╝░██╔══╝░░██║╚████║░░░██║░░░
--  ██║░╚███║███████╗░░░██║░░░  ███████╗░░╚██╔╝░░███████╗██║░╚███║░░░██║░░░
--  ╚═╝░░╚══╝╚══════╝░░░╚═╝░░░  ╚══════╝░░░╚═╝░░░╚══════╝╚═╝░░╚══╝░░░╚═╝░░░

RegisterNetEvent("group:client:receiveInvite", function(fromName, groupId, inviterId)
    currentInviteGroup = groupId
    currentInviterId = inviterId

    if isUiOpen then
        cursorActive = true
        SetNuiFocusKeepInput(false)
    end
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = "showInvite",
        fromName = fromName,
        groupId = groupId
    })

    TriggerEvent('v-groups:client:SendNotification', 'You have received an invite', 'success', 'bottom', '#141517', '#C1C2C5', 'check', 'green')
end)

-- Invite expired, or the inviter left/disconnected
RegisterNetEvent("group:client:inviteCancelled", function()
    if not currentInviterId then return end
    closeInvitePopup()
end)


RegisterNetEvent("group:client:updateGroup", function(groupData, leaderId, leaderName, maxSize, groupId)
    local myId = GetPlayerServerId(PlayerId())
    if not leaderId then
        leaderId = myId
        leaderName = GetPlayerName(PlayerId())
    end
    groupMembers = groupData or {}
    currentLeaderId = leaderId
    currentLeaderName = leaderName
    currentMaxSize = maxSize or currentMaxSize
    currentGroupId = groupId or currentGroupId
    SendNUIMessage({
        action = "setGroupMembers",
        members = groupMembers,
        leader = currentLeaderId,
        leaderName = currentLeaderName,
        maxSize = currentMaxSize,
        groupId = currentGroupId,
        myId = myId
    })
    if isUiOpen then
        updateNearbyPlayers()
    end
end)

RegisterNetEvent("group:client:inviteStatus", function(playerId, status)
    playerStatus[playerId] = status
    if isUiOpen then
        updateNearbyPlayers()
    end
end)

RegisterNetEvent("group:client:leftGroup", function()
    resetGroupState()
end)


RegisterNetEvent("group:client:receiveNearbyName", function(playerId, name)
    playerNames[playerId] = name
    pendingNames[playerId] = nil
end)


RegisterNetEvent("group:client:kicked", function()
    resetGroupState()
end)


-- Make sure we are always in a group (as host of our own one by default)
AddEventHandler("onClientResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        requestGroup()
    end
end)

AddEventHandler("playerSpawned", requestGroup)
RegisterNetEvent("QBCore:Client:OnPlayerLoaded", requestGroup)
RegisterNetEvent("esx:playerLoaded", function()
    requestGroup()
end)

-- Release NUI focus if the resource is restarted while the panel is open
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and (isUiOpen or currentInviterId) then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)




--  ░█████╗░██████╗░███████╗░█████╗░████████╗███████╗  ████████╗██╗░░██╗██████╗░███████╗░█████╗░██████╗░
--  ██╔══██╗██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██╔════╝  ╚══██╔══╝██║░░██║██╔══██╗██╔════╝██╔══██╗██╔══██╗
--  ██║░░╚═╝██████╔╝█████╗░░███████║░░░██║░░░█████╗░░  ░░░██║░░░███████║██████╔╝█████╗░░███████║██║░░██║
--  ██║░░██╗██╔══██╗██╔══╝░░██╔══██║░░░██║░░░██╔══╝░░  ░░░██║░░░██╔══██║██╔══██╗██╔══╝░░██╔══██║██║░░██║
--  ╚█████╔╝██║░░██║███████╗██║░░██║░░░██║░░░███████╗  ░░░██║░░░██║░░██║██║░░██║███████╗██║░░██║██████╔╝
--  ░╚════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝░░░╚═╝░░░╚══════╝  ░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═════╝░

CreateThread(function()
    while true do
        if isUiOpen then
            updateNearbyPlayers()
            Wait(1000)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if isUiOpen then
            if not cursorActive then
                -- keep Escape from opening the pause menu while game input is passed through
                DisableControlAction(0, 199, true)
                DisableControlAction(0, 200, true)
            end
            if #nearbyCache > 0 then
                for _, entry in ipairs(nearbyCache) do
                    if DoesEntityExist(entry.ped) then
                        local coords = GetEntityCoords(entry.ped)
                        DrawText3D(coords.x, coords.y, coords.z + 1.0, tostring(entry.id))
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)



RegisterNetEvent("v-groups:client:SendNotification")
AddEventHandler("v-groups:client:SendNotification", function(description, type, position, backgroundColor, color, icon, iconColor)
    SendNotification(description, type, position, backgroundColor, color, icon, iconColor)
end)


--  ░█████╗░░█████╗░███╗░░░███╗███╗░░░███╗░█████╗░███╗░░██╗██████╗░
--  ██╔══██╗██╔══██╗████╗░████║████╗░████║██╔══██╗████╗░██║██╔══██╗
--  ██║░░╚═╝██║░░██║██╔████╔██║██╔████╔██║███████║██╔██╗██║██║░░██║
--  ██║░░██╗██║░░██║██║╚██╔╝██║██║╚██╔╝██║██╔══██║██║╚████║██║░░██║
--  ╚█████╔╝╚█████╔╝██║░╚═╝░██║██║░╚═╝░██║██║░░██║██║░╚███║██████╔╝
--  ░╚════╝░░╚════╝░╚═╝░░░░░╚═╝╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

RegisterCommand("groups", function()
    toggleGroup()
end)


-- Get full group members table
exports('GetGroupMembers', function()
    return groupMembers
end)

-- Get leader server id
exports('GetGroupLeader', function()
    return currentLeaderId
end)

-- Get leader name
exports('GetGroupLeaderName', function()
    return currentLeaderName
end)

-- Get the current group's unique id
exports('GetGroupID', function()
    return currentGroupId
end)

-- Check if local player is leader
exports('IsGroupLeader', function()
    return GetPlayerServerId(PlayerId()) == currentLeaderId
end)

-- Check if a player is in your group
exports('IsPlayerInGroup', function(playerId)
    return isInGroup(playerId)
end)

-- Get group size
exports('GetGroupSize', function()
    return #groupMembers
end)

-- Get nearby players
exports('GetNearbyGroupPlayers', function()
    return nearbyPlayers
end)

-- Get invite/player statuses
exports('GetPlayerStatuses', function()
    return playerStatus
end)

-- Check if UI is open
exports('IsGroupUiOpen', function()
    return isUiOpen
end)

-- Open/close group UI
exports('ToggleGroupUi', function(state)
    if state ~= nil then
        setUiOpen(state and true or false)
    else
        toggleGroup()
    end
end)

-- Force refresh nearby players
exports('RefreshNearbyPlayers', function()
    updateNearbyPlayers()
end)

-- Open the group UI (no-op if already open)
exports('OpenGroup', function()
    if not isUiOpen then
        setUiOpen(true)
    end
end)

-- Get my current group data
exports('GetCurrentGroupData', function()
    return {
        members = groupMembers,
        leaderId = currentLeaderId,
        leaderName = currentLeaderName
    }
end)
