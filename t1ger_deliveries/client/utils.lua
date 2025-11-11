local ClientUtils = {}
local QBCore = exports['qb-core']:GetCoreObject()

local playerData = {}
local jobListeners = {}

local function broadcastJob(job)
    for _, handler in ipairs(jobListeners) do
        handler(job)
    end
end

local function detectJobBossGrade(job)
    if not job then return false end
    if job.isBoss ~= nil then return job.isBoss end
    if job.isboss then return true end
    local grade = job.grade
    if type(grade) == 'table' then
        if grade.isBoss ~= nil then
            return grade.isBoss
        end
        if grade.isboss then
            return true
        end
        if grade.level then
            return grade.level >= (Config.JobBossGrade or 4)
        end
        if grade.grade then
            return grade.grade >= (Config.JobBossGrade or 4)
        end
    end
    if type(grade) == 'number' then
        return grade >= (Config.JobBossGrade or 4)
    end
    return false
end

local function updateDeliveryIdentifier()
    if not playerData or not playerData.job then
        TriggerEvent('t1ger_deliveries:deliveryID', 0)
        return
    end

    local jobName = playerData.job.name
    if not jobName then
        TriggerEvent('t1ger_deliveries:deliveryID', 0)
        return
    end

    for i = 1, #Config.Companies do
        local company = Config.Companies[i]
        local society = Config.Society[company.society]
        if society and society.name == jobName then
            TriggerEvent('t1ger_deliveries:deliveryID', i)
            return
        end
    end

    TriggerEvent('t1ger_deliveries:deliveryID', 0)
end

local function refreshPlayerData(data)
    playerData = data or QBCore.Functions.GetPlayerData() or {}
    broadcastJob(playerData.job)
    updateDeliveryIdentifier()
end

if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoggedIn then
    refreshPlayerData()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerData = {}
    broadcastJob(nil)
    TriggerEvent('t1ger_deliveries:deliveryID', 0)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not playerData then
        playerData = {}
    end
    playerData.job = job
    broadcastJob(job)
    updateDeliveryIdentifier()
end)

RegisterNetEvent('QBCore:Client:SetPlayerData', function(data)
    refreshPlayerData(data)
end)

local function normaliseTypeFromMessage(message)
    if type(message) ~= 'string' then return 'inform' end
    local lower = message:lower()
    if lower:find('success') or lower:find('complete') or lower:find('completed') then
        return 'success'
    end
    if lower:find('error') or lower:find('fail') or lower:find('insufficient') or lower:find('not enough') then
        return 'error'
    end
    if lower:find('warning') or lower:find('alert') then
        return 'warning'
    end
    return 'inform'
end

RegisterNetEvent('t1ger_deliveries:notify', function(message)
    lib.notify({
        title = Lang['notify_title'] or 'Deliveries',
        description = message,
        type = normaliseTypeFromMessage(message)
    })
end)

RegisterNetEvent('t1ger_deliveries:notifyAdvanced', function(sender, subject, message)
    local title = sender or (Lang['notify_title'] or 'Deliveries')
    if subject and subject ~= '' then
        title = ('%s - %s'):format(title, subject)
    end
    lib.notify({
        title = title,
        description = message,
        type = normaliseTypeFromMessage(message)
    })
end)

function ClientUtils.RegisterJobListener(listener)
    jobListeners[#jobListeners + 1] = listener
    if playerData and playerData.job then
        listener(playerData.job)
    end
end

function ClientUtils.GetPlayerData()
    return playerData
end

function ClientUtils.HasJob(jobName)
    return playerData and playerData.job and playerData.job.name == jobName
end

function ClientUtils.IsPlayerBoss(jobName)
    if not playerData or not playerData.job then
        return false
    end
    if jobName and playerData.job.name ~= jobName then
        return false
    end
    return detectJobBossGrade(playerData.job)
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

function ClientUtils.LoadAnim(dict)
    if lib.requestAnimDict then
        lib.requestAnimDict(dict)
        return
    end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

function ClientUtils.LoadModel(model)
    if lib.requestModel then
        lib.requestModel(model)
        return
    end
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
end

function ClientUtils.LoadPtfxAsset(dict)
    if lib.requestNamedPtfxAsset then
        lib.requestNamedPtfxAsset(dict)
        return
    end
    RequestNamedPtfxAsset(dict)
    while not HasNamedPtfxAssetLoaded(dict) do
        Wait(10)
    end
end

_G.ClientUtils = ClientUtils

return ClientUtils
