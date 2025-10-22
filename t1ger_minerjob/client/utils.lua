local QBCore = exports['qb-core']:GetCoreObject()

PlayerData = {}

local function refreshPlayerData()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', refreshPlayerData)
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    refreshPlayerData()
end)

RegisterNetEvent('t1ger_minerjob:clientNotify', function(data)
    if type(data) == 'string' then
        lib.notify({ description = data })
        return
    end

    lib.notify(data)
end)

function ShowNotify(message, type, position)
    lib.notify({
        description = message,
        type = type or 'inform',
        position = position or 'top'
    })
end

function LoadAnim(dict)
    lib.requestAnimDict(dict)
end

function LoadModel(model)
    lib.requestModel(model)
end

function KeyString(input)
    local keyStr = GetControlInstructionalButton(0, input, true)
    return keyStr and keyStr:gsub('t_', '') or 'E'
end
