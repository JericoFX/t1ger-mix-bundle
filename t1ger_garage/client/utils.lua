-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()
PlayerData = {}

local function refreshPlayerData()
    PlayerData = QBCore.Functions.GetPlayerData()
end

CreateThread(function()
    refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:SetPlayerData', function(data)
    PlayerData = data
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not PlayerData then PlayerData = {} end
    PlayerData.job = job
end)

-- Notifications using ox_lib
RegisterNetEvent('t1ger_garage:notify', function(message, nType)
    lib.notify({
        title = 'Garage',
        description = message,
        type = nType or 'inform'
    })
end)

RegisterNetEvent('t1ger_garage:notifyAdvanced', function(sender, subject, message, textureDict, iconType)
    lib.notify({
        title = sender or subject or 'Garage',
        description = message,
        icon = textureDict,
        iconColor = iconType
    })
end)

function T1GER_GetJob(jobNames)
    if not PlayerData or not PlayerData.job then return false end
    for _, job in ipairs(jobNames) do
        if PlayerData.job.name == job then
            return true
        end
    end
    return false
end

function T1GER_CreateBlip(position, settings, id)
    if not settings or not settings.enable then return nil end
    local blip = AddBlipForCoord(position.x, position.y, position.z)
    SetBlipSprite(blip, settings.sprite)
    SetBlipScale(blip, settings.scale)
    if settings.color then
        SetBlipColour(blip, settings.color)
    end
    SetBlipDisplay(blip, settings.display or 4)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    if id then
        AddTextComponentString(('%s: %s'):format(settings.name, id))
    else
        AddTextComponentString(settings.name)
    end
    EndTextCommandSetBlipName(blip)
    return blip
end

function T1GER_DeleteVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

function T1GER_GetControlOfEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local timeout = 15
    NetworkRequestControlOfEntity(entity)
    while timeout > 0 and not NetworkHasControlOfEntity(entity) do
        Wait(10)
        NetworkRequestControlOfEntity(entity)
        timeout = timeout - 1
    end
end

function T1GER_LoadAnim(animDict)
    if lib and lib.requestAnimDict then
        lib.requestAnimDict(animDict)
        return
    end

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(5)
    end
end

function T1GER_LoadModel(model)
    if lib and lib.requestModel then
        lib.requestModel(model)
        return
    end

    if type(model) == 'string' then
        model = joaat(model)
    end
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(5)
    end
end

function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function T1GER_Trim(value)
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

function T1GER_CreatePed(pedType, model, x, y, z, heading)
    T1GER_LoadModel(model)
    local npc = CreatePed(pedType, model, x, y, z, heading, true, true)
    SetEntityAsMissionEntity(npc, true, true)
    return npc
end

function comma_value(number)
    local left, num, right = string.match(tostring(number), '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

exports('GetPlayerData', function()
    return PlayerData
end)
