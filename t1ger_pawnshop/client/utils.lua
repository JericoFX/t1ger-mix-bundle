-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

PlayerData = {}

local function refreshPlayerData()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
end

CreateThread(function()
    refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not PlayerData then PlayerData = {} end
    PlayerData.job = job
end)

RegisterNetEvent('t1ger_pawnshop:notify', function(message, notifType)
    if not message or message == '' then return end

    lib.notify({
        title = Config.NotificationTitle,
        description = message,
        type = notifType or 'inform'
    })
end)

-- Draw 3D Text (retained for backwards compatibility where needed)
function DrawText3Ds(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    if not onScreen then return end

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry('STRING')
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 500
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 80)
end

function LoadAnim(animDict)
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
end

function LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
end

function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function comma_value(n)
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

function KeyString(input)
    local keyStr = GetControlInstructionalButton(0, input, true):gsub('t_', '')
    return keyStr
end
