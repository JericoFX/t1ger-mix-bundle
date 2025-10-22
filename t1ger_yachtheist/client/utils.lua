-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------
local QBCore = exports['qb-core']:GetCoreObject()
PlayerData      = {}

-- Police Notify:
isCop = false
local streetName
local _

CreateThread(function()
        while not LocalPlayer.state.isLoggedIn do
                Wait(100)
        end
        PlayerData = QBCore.Functions.GetPlayerData()
        isCop = IsPlayerJobCop()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function(playerData)
        PlayerData = playerData or QBCore.Functions.GetPlayerData()
        isCop = IsPlayerJobCop()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerData.job = job
        isCop = IsPlayerJobCop()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
        PlayerData = val
        isCop = IsPlayerJobCop()
end)

RegisterNetEvent('t1ger_yachtheist:client:notify', function(msg, msgType)
        lib.notify({
                description = msg,
                type = msgType or 'inform'
        })
end)

function ShowNotify(msg, msgType)
        lib.notify({
                description = msg,
                type = msgType or 'inform'
        })
end

-- Is Player A cop?
function IsPlayerJobCop()
        if not PlayerData then return false end
        if not PlayerData.job then return false end
        if PlayerData.job.onduty ~= nil and PlayerData.job.onduty == false then return false end
        for k,v in pairs(Config.PoliceSettings.jobs) do
                if PlayerData.job.name == v then return true end
        end
        return false
end

RegisterNetEvent('t1ger_yachtheist:PoliceNotifyCL')
AddEventHandler('t1ger_yachtheist:PoliceNotifyCL', function(alert)
        if isCop then
                lib.notify({
                        title = Lang['dispatch_name'],
                        description = alert,
                        type = 'warning',
                        position = 'top-right'
                })
        end
end)

-- Thread for Police Notify
CreateThread(function()
        while true do
                Wait(2500)
                if cache.ped then
                        local pos = GetEntityCoords(cache.ped, false)
                        streetName,_ = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
                        streetName = GetStreetNameFromHashKey(streetName)
                end
        end
end)

-- Function for 3D text:
function DrawText3Ds(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 500
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 0, 0, 0, 80)
end

-- Round Fnction:
function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function comma_value(n)
        local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
        return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function drawRct(x, y, width, height, r, g, b, a)
        DrawRect(x + width/2, y + height/2, width, height, r, g, b, a)
end

-- Load Anim
function LoadAnim(animDict)
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
                Wait(10)
        end
end

-- Load Model
function LoadModel(model)
        RequestModel(model)
        while not HasModelLoaded(model) do
                Wait(10)
        end
end

-- Instructional Buttons:
function ButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

-- Button:
function Button(ControlButton)
    N_0xe83a3e3557a56640(ControlButton)
end
