-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local speedTrap = {
    active = false,
    zone = nil,
    lastScan = 0,
    lastPlate = nil,
    lastNotify = 0
}

local function convertSpeed(value)
    if Config.SpeedDetection.units == 'mph' then
        return value * 2.236936
    end
    return value * 3.6
end

local function notifySpeed(plate, speed, limit, vehicle)
    if speedTrap.lastPlate == plate and (GetGameTimer() - speedTrap.lastNotify) < (Config.SpeedDetection.scanInterval * 2) then
        return
    end

    speedTrap.lastPlate = plate
    speedTrap.lastNotify = GetGameTimer()

    local message = (Lang['speed_trap_message']):format(plate, math.floor(speed + 0.5), Config.SpeedDetection.units:upper(), limit)
    local notifType = speed > (limit + Config.SpeedDetection.limitBuffer) and 'error' or 'inform'
    TriggerEvent('t1ger_trafficpolicer:notify', message, notifType)
    TriggerEvent('t1ger_trafficpolicer:speedTrapResult', {
        plate = plate,
        speed = speed,
        limit = limit,
        vehicle = vehicle
    })
end

local function detectSpeed()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local origin = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local distance = Config.SpeedDetection.raycastDistance
    local target = origin + (forward * distance)
    local radius = Config.SpeedDetection.raycastRadius

    local rayHandle = StartShapeTestCapsule(origin.x, origin.y, origin.z + 1.0, target.x, target.y, target.z + 1.0, radius, 10, ped, 7)
    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

    if hit == 1 and entityHit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
        local limit = Config.SpeedDetection.limit
        local currentSpeed = convertSpeed(GetEntitySpeed(entityHit))

        if Config.SpeedDetection.notifyOnEveryCheck or currentSpeed > (limit + Config.SpeedDetection.limitBuffer) then
            local plate = (GetVehicleNumberPlateText(entityHit) or ''):gsub('%s+', '')
            notifySpeed(plate, currentSpeed, limit, entityHit)
        end
    end
end

local function disableTrap()
    if speedTrap.zone then
        speedTrap.zone:remove()
        speedTrap.zone = nil
    end
    speedTrap.active = false
    speedTrap.lastPlate = nil
    TriggerEvent('t1ger_trafficpolicer:notify', Lang['speed_trap_disabled'])
end

function ToggleSpeedTrap()
    if not Config.SpeedDetection.enable then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['speed_trap_not_configured'], 'error')
        return
    end

    if speedTrap.active then
        disableTrap()
        return
    end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local coords = GetEntityCoords(ped)
    speedTrap.active = true
    speedTrap.lastScan = 0

    speedTrap.zone = lib.zones.sphere({
        coords = coords,
        radius = Config.SpeedDetection.zoneRadius,
        debug = Config.Debug,
        inside = function()
            if not speedTrap.active then return end
            local now = GetGameTimer()
            if now - speedTrap.lastScan >= Config.SpeedDetection.scanInterval then
                speedTrap.lastScan = now
                detectSpeed()
            end
        end,
        onExit = function()
            if speedTrap.active then
                disableTrap()
            end
        end
    })

    TriggerEvent('t1ger_trafficpolicer:notify', Lang['speed_trap_enabled'])
end

RegisterNetEvent('onResourceStop')
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if speedTrap.active then
        disableTrap()
    end
end)

