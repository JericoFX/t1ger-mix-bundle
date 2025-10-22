-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

PlayerData = {}

-- Police Notify:
local isCop = false

local function refreshPlayerData()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
    isCop = IsPlayerJobCop()
end

CreateThread(function()
    refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    isCop = false
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not PlayerData then PlayerData = {} end
    PlayerData.job = job
    isCop = IsPlayerJobCop()
end)

RegisterNetEvent('QBCore:Client:SetDuty', function()
    isCop = IsPlayerJobCop()
end)

-- [[ ox_lib NOTIFICATION WRAPPER ]] --
RegisterNetEvent('t1ger_goldcurrency:notify', function(payload)
    local data = payload
    if type(data) == 'string' then
        data = {description = data, type = 'inform'}
    end

    data.type = data.type or 'inform'
    lib.notify(data)
end)

-- [[ ox_lib ADVANCED NOTIFICATION ]] --
RegisterNetEvent('t1ger_goldcurrency:notifyAdvanced', function(data)
    if type(data) ~= 'table' then return end
    lib.notify(data)
end)

function ShowNotify(msg, notifType)
    lib.notify({
        description = msg,
        type = notifType or 'inform'
    })
end

function AlertPoliceFunction()
    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end
    local coords = GetEntityCoords(ped)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetLabel = GetStreetNameFromHashKey(streetHash)
    local label = Lang['police_notify']
    TriggerServerEvent('t1ger_goldcurrency:PoliceNotifySV', coords, streetLabel, label)
end

RegisterNetEvent('t1ger_goldcurrency:PoliceNotifyCL', function(alert)
    if isCop then
        TriggerEvent('chat:addMessage', { args = {(Lang['dispatch_name']).. alert}})
    end
end)

-- [[ PHONE MESSAGES ]] --
function JobNotifyMSG(msg)
    local phoneNr = "T1GER#9080"
    PlaySoundFrontend(-1, "Menu_Accept", "Phone_SoundSet_Default", true)
    ShowNotify(Lang['new_msg_from']:format(phoneNr))
    TriggerServerEvent('gcPhone:sendMessage', phoneNr, msg)
end

RegisterNetEvent('t1ger_goldcurrency:PoliceNotifyBlip', function(targetCoords)
    if isCop and Config.PoliceSettings.blip.enable then
        local alpha = Config.PoliceSettings.blip.alpha
        local alertBlip = AddBlipForRadius(targetCoords.x, targetCoords.y, targetCoords.z, Config.PoliceSettings.blip.radius)
        SetBlipHighDetail(alertBlip, true)
        SetBlipColour(alertBlip, Config.PoliceSettings.blip.color)
        SetBlipAlpha(alertBlip, alpha)
        SetBlipAsShortRange(alertBlip, true)
        while alpha ~= 0 do
            Wait(Config.PoliceSettings.blip.time * 4)
            alpha = alpha - 1
            SetBlipAlpha(alertBlip, alpha)
            if alpha == 0 then
                RemoveBlip(alertBlip)
                return
            end
        end
    end
end)

-- Is Player A cop?
function IsPlayerJobCop()
    if not PlayerData or not PlayerData.job then return false end
    for k,v in pairs(Config.PoliceSettings.jobs) do
        if PlayerData.job.name == v and (not Config.PoliceSettings.onDutyOnly or PlayerData.job.onduty) then
            return true
        end
    end
    return false
end

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

-- Load Anim
function LoadAnim(animDict)
    lib.requestAnimDict(animDict)
end

-- Load Model:
function LoadModel(model)
    lib.requestModel(model)
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

-- Function to return key str:
function KeyString(input)
    local output = '~r~[E]~s~'
    if input == 'E' then output = '~r~[E]~s~'
    elseif input == 'G' then output = '~r~[G]~s~'
    elseif input == 'H' then output = '~r~[H]~s~'
    elseif input == 'ENTER' then output = '~r~[ENTER]~s~'
    elseif input == 'DELETE' then output = '~r~[DELETE]~s~'
    elseif input == 'F7' then output = '~r~[F7]~s~'
    elseif input == 'F6' then output = '~r~[F6]~s~'
    elseif input == 'F5' then output = '~r~[F5]~s~'
    elseif input == 'F4' then output = '~r~[F4]~s~'
    elseif input == 'F3' then output = '~r~[F3]~s~'
    elseif input == 'F2' then output = '~r~[F2]~s~'
    elseif input == 'F1' then output = '~r~[F1]~s~'
    elseif input == 'Y' then output = '~r~[Y]~s~'
    elseif input == 'Z' then output = '~r~[Z]~s~'
    elseif input == 'U' then output = '~r~[U]~s~'
    elseif input == 'K' then output = '~r~[K]~s~'
    elseif input == 'L' then output = '~r~[L]~s~'
    elseif input == 'J' then output = '~r~[J]~s~'
    elseif input == 'M' then output = '~r~[M]~s~'
    elseif input == 'B' then output = '~r~[B]~s~'
    elseif input == 'X' then output = '~r~[X]~s~'
    elseif input == 'N' then output = '~r~[N]~s~'
    elseif input == 'EQUALS' then output = '~r~[+]~s~'
    elseif input == 'MINUS' then output = '~r~[-]~s~'
    elseif input == 'PAGEUP' then output = '~r~[PAGEUP]~s~'
    elseif input == 'PAGEDOWN' then output = '~r~[PAGEDOWN]~s~'
    elseif input == 'LEFTCTRL' then output = '~r~[CTRL]~s~'
    elseif input == 'LEFTSHIFT' then output = '~r~[SHIFT]~s~'
    elseif input == 'LEFTALT' then output = '~r~[ALT]~s~'
    elseif input == 'SPACE' then output = '~r~[SPACE]~s~'
    elseif input == 'BACKSPACE' then output = '~r~[BACKSPACE]~s~'
    elseif input == 'TAB' then output = '~r~[TAB]~s~'
    elseif input == 'CAPSLOCK' then output = '~r~[CAPS]~s~'
    elseif input == 'RIGHTCTRL' then output = '~r~[CTRL]~s~'
    elseif input == 'NUMPAD4' then output = '~r~[4]~s~'
    elseif input == 'NUMPAD5' then output = '~r~[5]~s~'
    elseif input == 'NUMPAD6' then output = '~r~[6]~s~'
    elseif input == 'NUMPAD+ ' then output = '~r~[+]~s~'
    elseif input == 'NUMPAD-' then output = '~r~[-]~s~'
    elseif input == 'NUMPAD7' then output = '~r~[7]~s~'
    elseif input == 'NUMPAD8' then output = '~r~[8]~s~'
    elseif input == 'NUMPAD9' then output = '~r~[9]~s~'
    elseif input == 'NUMPAD/' then output = '~r~[/]~s~'
    elseif input == 'NUMPAD*' then output = '~r~[*]~s~'
    elseif input == 'NUMPADENTER' then output = '~r~[ENTER]~s~'
    elseif input == 'HOME' then output = '~r~[HOME]~s~'
    elseif input == 'DELETE' then output = '~r~[DELETE]~s~'
    elseif input == 'INSERT' then output = '~r~[INSERT]~s~'
    elseif input == 'END' then output = '~r~[END]~s~'
    elseif input == 'SCROLLLOCK' then output = '~r~[SCROLL]~s~'
    elseif input == 'F9' then output = '~r~[F9]~s~'
    elseif input == 'F10' then output = '~r~[F10]~s~'
    elseif input == 'F11' then output = '~r~[F11]~s~'
    elseif input == 'F12' then output = '~r~[F12]~s~'
    end
    return output
end
