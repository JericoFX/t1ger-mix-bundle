-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

local QBCore = exports['qb-core']:GetCoreObject()
PlayerData = {}

local function cachePlayerJob()
if not PlayerData or not PlayerData.job then return end
for i = 1, #Config.TowServices do
local towtruckerJob = Config.Society[Config.TowServices[i].society].name
if PlayerData.job.name == towtruckerJob then
TriggerEvent('t1ger_towtrucker:setTowID', i)
return
end
end
TriggerEvent('t1ger_towtrucker:setTowID', 0)
end

local function setPlayerData(data)
PlayerData = data or {}
cachePlayerJob()
end

CreateThread(function()
setPlayerData(QBCore.Functions.GetPlayerData())
if Config.Debug then
Wait(2000)
TriggerServerEvent('t1ger_towtrucker:debugSV')
end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
setPlayerData(QBCore.Functions.GetPlayerData())
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
if not PlayerData then PlayerData = {} end
PlayerData.job = job
cachePlayerJob()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
setPlayerData(data)
end)

local function notify(message, notifType, opts)
if not message then return end
lib.notify({
title = opts and opts.title or 'Tow Trucker',
description = message,
type = notifType or 'inform',
duration = opts and opts.duration or 5000,
icon = opts and opts.icon,
iconColor = opts and opts.iconColor
})
end

-- Notification
RegisterNetEvent('t1ger_towtrucker:notify', function(msg, notifType)
notify(msg, notifType)
end)

-- Advanced Notification
RegisterNetEvent('t1ger_towtrucker:notifyAdvanced', function(textureDict, textureName, iconType, title, showInBrief, subtitle, message)
notify(message, iconType == 1 and 'success' or 'inform', {
title = title or subtitle or 'Tow Trucker',
duration = showInBrief and 8000 or 5000,
icon = textureName ~= '' and textureName or 'truck-pickup'
})
end)

function T1GER_DrawTxt(x, y, z, text)
	local boolean, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING"); SetTextCentre(1); AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text) / 500)
    DrawRect(_x, (_y + 0.0125), (0.015 + factor), 0.03, 0, 0, 0, 80)
end

function T1GER_GetControlOfEntity(entity)
	local netTime = 15
	NetworkRequestControlOfEntity(entity)
	while not NetworkHasControlOfEntity(entity) and netTime > 0 do 
		NetworkRequestControlOfEntity(entity)
		Citizen.Wait(100)
		netTime = netTime -1
	end
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
if not PlayerData then return false end
if not PlayerData.job then return false end
if PlayerData.job.name == name then
return true
end
return false
end

function T1GER_GetJob(table)
if not PlayerData then return false end
if not PlayerData.job then return false end
for k,v in pairs(table) do
if PlayerData.job.name == v then
return true
end
end
return false
end

function T1GER_GetJobGrade()
if not PlayerData or not PlayerData.job then return 0 end
local grade = PlayerData.job.grade
if type(grade) == 'table' then
return grade.level or grade.grade or 0
end
return grade or 0
end

function T1GER_IsBoss()
if not PlayerData or not PlayerData.job then return false end
if PlayerData.job.isboss ~= nil then
return PlayerData.job.isboss
end
local grade = PlayerData.job.grade
if type(grade) == 'table' then
if grade.isboss ~= nil then return grade.isboss end
return (grade.name and grade.name:lower() == 'boss') or (grade.level and grade.level >= (Config.BossGrade or grade.level))
end
return grade ~= nil and grade >= (Config.BossGrade or grade)
end

-- Function to Display Help Text:
function DisplayHelpText(str)
	SetTextComponentFormat("STRING")
	AddTextComponentString(str)
	DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

-- Round Fnction:
function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Comma Function:
function comma_value(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

