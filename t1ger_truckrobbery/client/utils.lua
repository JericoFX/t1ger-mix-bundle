-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

PlayerState = {
    data = {},
    isCop = false
}

local function refreshPlayerState()
    local data = QBCore.Functions.GetPlayerData() or {}
    PlayerState.data = data
    PlayerState.isCop = false

    local job = data.job and data.job.name
    if job then
        for _, name in ipairs(Config.TruckRobbery.police.jobs) do
            if name == job then
                PlayerState.isCop = true
                break
            end
        end
    end

    TriggerEvent('t1ger_truckrobbery:client:playerState', PlayerState)
end

CreateThread(function()
    while not LocalPlayer or not LocalPlayer.state do
        Wait(250)
    end

    while not LocalPlayer.state.isLoggedIn do
        Wait(250)
    end

    refreshPlayerState()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshPlayerState)
RegisterNetEvent('QBCore:Client:SetPlayerData', function(data)
    PlayerState.data = data
    refreshPlayerState()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerState.data.job = job
    refreshPlayerState()
end)

lib.onCache('ped', function(value)
    player = value
end)

function NotifyPlayer(type, description, title)
    if not description or description == '' then return end
    lib.notify({
        type = type or 'inform',
        description = description,
        title = title
    })
end

function LoadAnim(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

function LoadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if HasModelLoaded(hash) then return hash end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    return hash
end

function ReleaseModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    SetModelAsNoLongerNeeded(hash)
end

function DeleteEntityIfExists(entity)
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

function PlayerIsCop()
    return PlayerState.isCop
end

function GetCitizenId()
    return PlayerState.data and PlayerState.data.citizenid
end
