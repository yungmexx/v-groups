Config = Config or {}

-- Framework
-- Options: 'auto_detect', 'qb', 'qbox', 'esx', 'standalone'
Config.Framework = 'auto_detect'

-- Notifications
-- Options: 'qb', 'ox', 'gta'
Config.Notification = 'gta'

-- Seconds before an unanswered invite expires
Config.InviteTimeout = 30


local function ShowNotification(text)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end

function SendNotification(description, type, position, backgroundColor, color, icon, iconColor)
    if Config.Notification == "qb" then
        if type == 'info' then
            type = 'primary'
        end
        TriggerEvent('QBCore:Notify', description, type)
    elseif Config.Notification == "ox" then
        if type == 'info' then
            type = 'inform'
        end
        exports.ox_lib:notify({
            description = description,
            type = type,
            position = position,
            duration = 5000,
            style = {
                backgroundColor = backgroundColor,
                color = color,
                [".description"] = {
                color = "#909296"
                }
            },
            icon = icon,
            iconColor = iconColor
        })
    else
        ShowNotification(description)
    end
end
