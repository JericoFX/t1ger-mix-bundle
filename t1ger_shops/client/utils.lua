-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 
local QBCore = exports['qb-core']:GetCoreObject()
PlayerData = {}

local function updateOwnedShop()
        if not PlayerData or not PlayerData.job then
                TriggerEvent('t1ger_shops:setShopID', 0)
                return
        end

        for i = 1, #Config.Shops do
                local jobName = Config.Society[Config.Shops[i].society].job
                if jobName and PlayerData.job.name == jobName then
                        TriggerEvent('t1ger_shops:setShopID', i)
                        return
                end
        end

        TriggerEvent('t1ger_shops:setShopID', 0)
end

local function refreshPlayerData()
        PlayerData = QBCore.Functions.GetPlayerData() or {}
        updateOwnedShop()
        if Config.Debug then
                CreateThread(function()
                        Wait(2000)
                        TriggerServerEvent('t1ger_shops:debugSV')
                end)
        end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
        PlayerData = {}
        TriggerEvent('t1ger_shops:setShopID', 0)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerData.job = job
        updateOwnedShop()
end)

AddEventHandler('onResourceStart', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        if LocalPlayer and LocalPlayer.state['isLoggedIn'] then
                refreshPlayerData()
        end
end)

-- Notification
RegisterNetEvent('t1ger_shops:notify', function(msg, opts)
        lib.notify({
                title = opts and opts.title or 'Shops',
                description = msg,
                type = opts and opts.type or 'inform'
        })
end)

-- Advanced Notification fallback (maintained for backwards compatibility)
RegisterNetEvent('t1ger_shops:notifyAdvanced', function(sender, subject, msg)
        lib.notify({
                title = subject or sender or 'Shops',
                description = msg,
                type = 'inform'
        })
end)

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

-- Load Anim
function T1GER_LoadAnim(animDict)
	RequestAnimDict(animDict); while not HasAnimDictLoaded(animDict) do Citizen.Wait(1) end
end

-- Load Model
function T1GER_LoadModel(model)
	RequestModel(model); while not HasModelLoaded(model) do Citizen.Wait(1) end
end

function T1GER_isJob(name)
        if not PlayerData or not PlayerData.job then return false end
        return PlayerData.job.name == name
end

function T1GER_GetJob(table)
        if not PlayerData or not PlayerData.job then return false end
        for _, v in pairs(table) do
                if PlayerData.job.name == v then
                        return true
                end
        end
        return false
end

-- Round function
function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Comma function
function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end
