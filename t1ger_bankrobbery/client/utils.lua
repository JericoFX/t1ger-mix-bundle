local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local playerJob = {}
local copJobs = {}
local isPlayerCop = false
local textUI, textLabel = false, nil

local function sanitiseLabel(text)
    if type(text) ~= 'string' then
        return text
    end
    text = text:gsub('~.-~', '')
    text = text:gsub('%s+', ' ')
    return text
end

---@param job string
local function isCopJob(job)
    if not job then return false end
    if next(copJobs) == nil then
        for _, jobName in ipairs(Config.PoliceJobs) do
            copJobs[jobName] = true
        end
    end
    return copJobs[job] or false
end

local function refreshPlayerData(data)
    PlayerData = data or QBCore.Functions.GetPlayerData() or {}
    playerJob = PlayerData.job or {}
    isPlayerCop = isCopJob(playerJob.name)
end

CreateThread(function()
    repeat
        refreshPlayerData()
        Wait(500)
    until PlayerData.citizenid or LocalPlayer.state.isLoggedIn
    CreateBankBlips()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
    CreateBankBlips()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    playerJob = {}
    isPlayerCop = false
    HideInteraction()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    playerJob = job
    isPlayerCop = isCopJob(job and job.name)
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    if playerJob then
        playerJob.onduty = onDuty
    end
end)

RegisterNetEvent('t1ger_bankrobbery:notify', function(message, type)
    if not message or message == '' then return end
    lib.notify({
        title = Lang['notify_title'] or 'Bank Robbery',
        description = message,
        type = type or 'inform'
    })
end)

RegisterNetEvent('t1ger_bankrobbery:notifyAdvanced', function(sender, subject, message, textureDict, iconType)
    lib.notify({
        title = sender or subject or (Lang['notify_title'] or 'Bank Robbery'),
        description = message,
        icon = textureDict,
        iconColor = iconType,
    })
end)

RegisterNetEvent('t1ger_bankrobbery:police_notify', function(name)
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local streetName = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    local message = Lang['police_notify']:format(name, streetName)
    TriggerServerEvent('t1ger_bankrobbery:sendPoliceAlertSV', coords, message)
end)

RegisterNetEvent('t1ger_bankrobbery:sendPoliceAlertCL', function(targetCoords, message)
    if not isPlayerCop then return end
    lib.notify({
        title = Lang['dispatch_name'],
        description = message,
        type = 'warning'
    })

    local cfg = Config.AlertBlip
    if not cfg.Show then return end

    local alpha = cfg.Alpha
    local blip = AddBlipForRadius(targetCoords.x, targetCoords.y, targetCoords.z, cfg.Radius)
    SetBlipHighDetail(blip, true)
    SetBlipColour(blip, cfg.Color)
    SetBlipAlpha(blip, alpha)
    SetBlipAsShortRange(blip, true)

    while alpha > 0 do
        Wait(cfg.Time * 4)
        alpha -= 1
        SetBlipAlpha(blip, alpha)
    end
    RemoveBlip(blip)
end)

function ShowInteraction(label)
    label = sanitiseLabel(label)
    if textLabel == label then return end
    textLabel = label
    if not textUI then
        lib.showTextUI(label, {
            icon = 'hand',
            style = {
                borderRadius = 6,
                backgroundColor = '#0f111a',
                color = '#ffffff'
            }
        })
        textUI = true
    else
        lib.updateTextUI(label)
    end
end

function HideInteraction()
    if not textUI then return end
    textUI = false
    textLabel = nil
    lib.hideTextUI()
end

function IsPlayerCop()
    return isPlayerCop
end

function GetPlayerJob()
    return playerJob
end

function GetPlayerData()
    return PlayerData
end

function T1GER_CreateBlip(pos, data)
    local blip
    if data.enable then
        blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, data.sprite)
        SetBlipDisplay(blip, data.display)
        SetBlipScale(blip, data.scale)
        SetBlipColour(blip, data.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(data.label or data.name)
        EndTextCommandSetBlipName(blip)
        if data.route then
            SetBlipRoute(blip, data.route)
            SetBlipRouteColour(blip, data.color)
        end
    end
    return blip
end

function T1GER_GetControlOfEntity(entity)
    local timeout = 15
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and timeout > 0 do
        Wait(100)
        NetworkRequestControlOfEntity(entity)
        timeout -= 1
    end
end

function T1GER_CreatePed(type, model, x, y, z, heading)
    T1GER_LoadModel(model)
    local npc = CreatePed(type, GetHashKey(model), x, y, z, heading, true, true)
    SetEntityAsMissionEntity(npc, true, true)
    return npc
end

function T1GER_LoadAnim(animDict)
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(1) end
end

function T1GER_LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(1) end
end

function T1GER_LoadPtfxAsset(dict)
    RequestNamedPtfxAsset(dict)
    while not HasNamedPtfxAssetLoaded(dict) do Wait(1) end
end

function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

exports('GetPlayerData', GetPlayerData)
exports('IsPlayerCop', IsPlayerCop)
exports('ShowInteraction', ShowInteraction)
exports('HideInteraction', HideInteraction)
