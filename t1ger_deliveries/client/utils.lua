local ClientUtils = {}
local QBCore = exports['qb-core']:GetCoreObject()
local SharedUtils = SharedUtils

local playerData = QBCore.Functions.GetPlayerData() or {}
local jobListeners = {}

local function broadcastJob(job)
    for _, handler in ipairs(jobListeners) do
        handler(job)
    end
end

function ClientUtils.RegisterJobListener(listener)
    table.insert(jobListeners, listener)
-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 
local QBCore = exports['qb-core']:GetCoreObject()
PlayerData = {}

CreateThread(function()
PlayerData = QBCore.Functions.GetPlayerData()
UpdateDeliveryIdentifier()

if Config.Debug then
Wait(3000)
TriggerServerEvent('t1ger_deliveries:debugSV')
end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
PlayerData = QBCore.Functions.GetPlayerData()
UpdateDeliveryIdentifier()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
PlayerData.job = job
UpdateDeliveryIdentifier()
end)

RegisterNetEvent('QBCore:Client:SetPlayerData', function(val)
PlayerData = val
UpdateDeliveryIdentifier()
end)

function UpdateDeliveryIdentifier()
if not PlayerData or not PlayerData.job then return end
for i = 1, #Config.Companies do
local deliveryJob = Config.Society[Config.Companies[i].society].name
if PlayerData.job.name == deliveryJob then
TriggerEvent('t1ger_deliveries:deliveryID', i)
return
end
end
TriggerEvent('t1ger_deliveries:deliveryID', 0)
end

local function getNotifyType(msg)
if type(msg) ~= 'string' then return 'inform' end
msg = msg:lower()
if msg:find('success') or msg:find('completed') or msg:find('purchased') then
return 'success'
elseif msg:find('error') or msg:find('not enough') or msg:find('fail') or msg:find('mismatch') then
return 'error'
elseif msg:find('warning') or msg:find('alert') then
return 'warning'
end
return 'inform'
end

RegisterNetEvent('t1ger_deliveries:notify', function(msg)
lib.notify({
title = Lang['notify_title'] or 'Deliveries',
description = msg,
type = getNotifyType(msg)
})
end)

RegisterNetEvent('t1ger_deliveries:notifyAdvanced', function(sender, subject, msg, textureDict, iconType)
lib.notify({
title = sender or (Lang['notify_title'] or 'Deliveries'),
description = subject and (subject .. '\n' .. msg) or msg,
type = getNotifyType(msg)
})
end)

    if playerData and playerData.job then
        listener(playerData.job)
    end
end

function ClientUtils.GetPlayerData()
    return playerData
end

function ClientUtils.HasJob(jobName)
    if not playerData or not playerData.job then
        return false
    end

    return playerData.job.name == jobName
end

function ClientUtils.IsPlayerBoss(jobName)
    if not playerData or not playerData.job then
        return false
    end

    if playerData.job.name ~= jobName then
        return false
    end

    return playerData.job.isboss == true or (playerData.job.grade and playerData.job.grade.level and playerData.job.grade.level >= (Config.JobBossGrade or 4))
-- Load Anim
function T1GER_LoadAnim(animDict)
        if lib and lib.requestAnimDict then
                lib.requestAnimDict(animDict)
                return
        end
        RequestAnimDict(animDict); while not HasAnimDictLoaded(animDict) do Citizen.Wait(1) end
end

-- Load Model
function T1GER_LoadModel(model)
        if lib and lib.requestModel then
                lib.requestModel(model)
                return
        end
        RequestModel(model); while not HasModelLoaded(model) do Citizen.Wait(1) end
end

-- Load Ptfx
function T1GER_LoadPtfxAsset(dict)
        if lib and lib.requestNamedPtfxAsset then
                lib.requestNamedPtfxAsset(dict)
                return
        end
        RequestNamedPtfxAsset(dict); while not HasNamedPtfxAssetLoaded(dict) do Citizen.Wait(1) end
end

function ClientUtils.Notify(description, type)
    lib.notify({
        description = description,
        type = type or 'inform',
        position = 'top'
    })
end

function ClientUtils.OpenContext(id, title, options)
    lib.registerContext({
        id = id,
        title = title,
        options = options,
        position = 'top-right'
    })

    lib.showContext(id)
end

function ClientUtils.OpenInput(options)
    return lib.inputDialog(options.title, options.fields)
end

function ClientUtils.ShowText(message)
    lib.showTextUI(message)
end

function ClientUtils.HideText()
    if lib.isTextUIOpen() then
        lib.hideTextUI()
    end
end

function ClientUtils.CreateTimer(duration, onEnd)
    return lib.timer(duration, onEnd, true)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerData = QBCore.Functions.GetPlayerData()
    broadcastJob(playerData and playerData.job or nil)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerData = {}
    broadcastJob(nil)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not playerData then
        playerData = {}
    end

    playerData.job = job
    broadcastJob(job)
end)

_G.ClientUtils = ClientUtils

return ClientUtils
