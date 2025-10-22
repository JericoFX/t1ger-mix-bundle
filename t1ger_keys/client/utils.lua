-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------
local QBCore = exports['qb-core']:GetCoreObject()

PlayerData = {}
isCop = false

local function RefreshPlayerData()
        PlayerData = QBCore.Functions.GetPlayerData() or {}
        isCop = IsPlayerJobCop()
end

Citizen.CreateThread(function()
        RefreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        RefreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerData.job = job or (QBCore.Functions.GetPlayerData() or {}).job
        isCop = IsPlayerJobCop()
end)

-- Notification
local function ShowNotification(message, notifyType)
        if lib and lib.notify then
                lib.notify({
                        description = message,
                        type = notifyType or 'inform'
                })
        else
                QBCore.Functions.Notify(message, notifyType or 'primary', 5000)
        end
end

RegisterNetEvent('t1ger_keys:notify')
AddEventHandler('t1ger_keys:notify', function(msg, notifyType)
        ShowNotification(msg, notifyType)
end)

-- Advanced Notification
RegisterNetEvent('t1ger_keys:notifyAdvanced')
AddEventHandler('t1ger_keys:notifyAdvanced', function(sender, subject, msg, textureDict, iconType)
        if lib and lib.notify then
                lib.notify({
                        title = sender or subject,
                        description = msg,
                        type = 'inform'
                })
        else
                local prefix = sender or subject or ''
                if prefix ~= '' then
                        prefix = prefix .. ': '
                end
                QBCore.Functions.Notify(prefix .. msg, 'inform', 5000)
        end
end)

-- Player Notification when vehicle is being stolen
RegisterNetEvent('t1ger_keys:player_notify')
AddEventHandler('t1ger_keys:player_notify', function(plate, identifier)
        local coords = GetEntityCoords(PlayerPedId(), false)
        local street_name = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
        local message = Lang['vehicle_alarm_triggered']:format(plate, street_name)
        -- send notification
        TriggerServerEvent('t1ger_keys:sendPlayerAlert', coords, street_name, message, plate, identifier)
end)

-- Police Notification
RegisterNetEvent('t1ger_keys:police_notify')
AddEventHandler('t1ger_keys:police_notify', function(msg, vehicle)
        local message = msg
        if Config.Police.EnableAlerts then
                local coords = GetEntityCoords(PlayerPedId(), false)
                local street_name = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
                -- stolen NPC cars:
                if vehicle ~= nil and DoesEntityExist(vehicle) then
                        local plate = GetVehicleNumberPlateText(vehicle)
                        local make = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
                        local color1, color2 = GetVehicleColours(vehicle)
                        if color1 == 0 then color1 = 1 end; if color2 == 0 then color2 = 2 end
                        if color1 == -1 then color1 = 158 end; if color2 == -1 then color2 = 158 end
                        if message == 'steal' then
                                message = Lang['police_notification1']:format(street_name, make, plate, Config.VehicleColors[color1], Config.VehicleColors[color2])
                        elseif message == 'lockpick' then
                                message = Lang['police_notification2']:format(street_name, make, plate, Config.VehicleColors[color1], Config.VehicleColors[color2])
                        end
                end
                -- send notification
                TriggerServerEvent('t1ger_keys:sendPoliceAlert', coords, street_name, message)
        end
end)

-- Police Notification Blip:
RegisterNetEvent('t1ger_keys:sendPoliceAlertCL')
AddEventHandler('t1ger_keys:sendPoliceAlertCL', function(target_coords, message)
        if isCop then
                TriggerEvent('chat:addMessage', { args = {(Lang['dispatch_name']).. message}})
                -- blip
                local cfg = Config.Police.AlertBlip
                if cfg.Show then
                        local alpha = cfg.Alpha
                        local blip = AddBlipForRadius(target_coords.x, target_coords.y, target_coords.z, cfg.Radius)
                        SetBlipHighDetail(blip, true)
                        SetBlipColour(blip, cfg.Color)
                        SetBlipAlpha(blip, alpha)
                        SetBlipAsShortRange(blip, true)
                        while alpha ~= 0 do
                                Citizen.Wait(cfg.Time * 4)
                                alpha = alpha - 1
                                SetBlipAlpha(blip, alpha)
                                if alpha == 0 then
                                        RemoveBlip(blip)
                                        return
                                end
                        end
                end
        end
end)

-- Player Client Notification:
RegisterNetEvent('t1ger_keys:sendPlayerAlertCL')
AddEventHandler('t1ger_keys:sendPlayerAlertCL', function(target_coords, message, plate)
        TriggerEvent('chat:addMessage', { args = {(Lang['alarm_central']).. message}})
        -- blip
        local cfg = Config.AlarmShop.alertBlip
        if cfg.Show then
                local alpha = cfg.Alpha
                local blip = AddBlipForRadius(target_coords.x, target_coords.y, target_coords.z, cfg.Radius)
                SetBlipHighDetail(blip, true)
                SetBlipColour(blip, cfg.Color)
                SetBlipAlpha(blip, alpha)
                SetBlipAsShortRange(blip, true)
                while alpha ~= 0 do
                        Citizen.Wait(cfg.Time * 4)
                        alpha = alpha - 1
                        SetBlipAlpha(blip, alpha)
                        if alpha == 0 then
                                RemoveBlip(blip)
                                return
                        end
                end
        end
end)

function T1GER_GetJob(table)
        if not PlayerData then return false end
        if not PlayerData.job then return false end
        for k,v in pairs(table) do
                if PlayerData.job.name == v then
                        return true
                end
        end
        return false
end

-- Is Player A cop?
function IsPlayerJobCop()
        if not PlayerData then return false end
        if not PlayerData.job then return false end
        for k,v in pairs(Config.Police.Jobs) do
                if PlayerData.job.name == v then return true end
        end
        return false
end

-- Draw 3D Text:
function T1GER_DrawTxt(x, y, z, text)
        local boolean, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING"); SetTextCentre(1); AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text) / 500)
    DrawRect(_x, (_y + 0.0125), (0.015 + factor), 0.03, 0, 0, 0, 80)
end

-- Create Blip:
function T1GER_CreateBlip(pos, data)
        local blip = nil
        if data.enable then
                blip = AddBlipForCoord(pos.x, pos.y, pos.z)
                SetBlipSprite(blip, data.sprite)
                SetBlipDisplay(blip, data.display)
                SetBlipScale(blip, data.scale)
                SetBlipColour(blip, data.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(data.label)
                EndTextCommandSetBlipName(blip)
        end
        return blip
end

function T1GER_GetControlOfEntity(entity)
        local netTime = 15
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) and netTime > 0 do
                NetworkRequestControlOfEntity(entity)
                Citizen.Wait(1)
                netTime = netTime -1
        end
end

-- Load Anim
function T1GER_LoadAnim(animDict)
        if lib and lib.requestAnimDict then
                lib.requestAnimDict(animDict)
                return
        end
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
                Citizen.Wait(1)
        end
end

-- Load Model
function T1GER_LoadModel(model)
        if lib and lib.requestModel then
                lib.requestModel(model)
                return
        end
        RequestModel(model)
        while not HasModelLoaded(model) do
                Citizen.Wait(1)
        end
end

function T1GER_Trim(value)
        return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end
