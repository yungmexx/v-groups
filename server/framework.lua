QBCore = nil
ESX = nil

local framework = Config.Framework or 'auto_detect'

if framework == 'auto_detect' then
    if GetResourceState("qbx_core") == "started" then
        framework = 'qbox'
    elseif GetResourceState("qb-core") == "started" then
        framework = 'qb'
    elseif GetResourceState("es_extended") == "started" then
        framework = 'esx'
    else
        framework = 'standalone'
    end
end

if framework == 'qb' then
    QBCore = exports["qb-core"]:GetCoreObject()
elseif framework == 'esx' then
    ESX = exports["es_extended"]:getSharedObject()
end


--  ░██████╗░██████╗░░█████╗░░█████╗░██████╗░███████╗
--  ██╔═══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝
--  ██║██╗██║██████╦╝██║░░╚═╝██║░░██║██████╔╝█████╗░░
--  ╚██████╔╝██╔══██╗██║░░██╗██║░░██║██╔══██╗██╔══╝░░
--  ░╚═██╔═╝░██████╦╝╚█████╔╝╚█████╔╝██║░░██║███████╗
--  ░░░╚═╝░░░╚═════╝░░╚════╝░░╚════╝░╚═╝░░╚═╝╚══════╝


GetPlayer = function(src)
    if framework == 'qbox' then
        return exports.qbx_core:GetPlayer(src)
    elseif QBCore then
        return QBCore.Functions.GetPlayer(src)
    elseif ESX then
        return ESX.GetPlayerFromId(src)
    end
    return nil
end

-- true once the player has a loaded character (always true when standalone)
IsPlayerLoaded = function(src)
    if framework == 'standalone' then
        return GetPlayerName(src) ~= nil
    end
    return GetPlayer(src) ~= nil
end

-- Character name, falls back to the FiveM name
GetCharName = function(src)
    local Player = GetPlayer(src)
    if Player then
        local charinfo = Player.PlayerData and Player.PlayerData.charinfo
        if charinfo then
            return (charinfo.firstname or "Unknown") .. " " .. (charinfo.lastname or "")
        elseif Player.getName then
            return Player.getName()
        end
    end
    return GetPlayerName(src) or "Unknown"
end
