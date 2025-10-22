-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

PlayerData = {}
local textUIVisible = false
local currentUIText
local currentOwner

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
    PlayerData.job = job
end)

local function buildNotification(data)
    if type(data) == 'string' then
        data = { description = data }
    end

    data.type = data.type or 'inform'
    data.description = data.description or ''
    data.position = data.position or 'top'

    return data
end

RegisterNetEvent('t1ger_minerjob:client:notify', function(data)
    if not data then return end
    lib.notify(buildNotification(data))
end)

function ShowNotify(data)
    lib.notify(buildNotification(data))
end

function ShowInteraction(text, owner)
    if textUIVisible and currentUIText == text and currentOwner == owner then
        return
    end

    currentUIText = text
    currentOwner = owner
    lib.showTextUI(text)
    textUIVisible = true
end

function HideInteraction(owner)
    if not textUIVisible then return end
    if owner and currentOwner and owner ~= currentOwner then return end

    lib.hideTextUI()
    textUIVisible = false
    currentUIText = nil
    currentOwner = nil
end

function RequestAnim(dict)
    lib.requestAnimDict(dict)
end

function RequestModel(model)
    lib.requestModel(model)
end

local controlLabels = {
    [38] = 'E',
    [51] = 'E',
    [47] = 'G',
    [23] = 'F',
    [74] = 'H',
    [29] = 'B',
}

function KeyString(input)
    local label = controlLabels[input]
    if not label then
        local controlName = GetControlInstructionalButton(0, input, true)
        if controlName then
            local parsed = controlName:match('~INPUT_(.+)~')
            if parsed then
                label = parsed
            end
        end
    end

    if not label or label == '' then
        label = tostring(input)
    end

    return ('[%s]'):format(label)
end
