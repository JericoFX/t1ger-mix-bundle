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
