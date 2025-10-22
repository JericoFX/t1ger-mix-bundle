-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local cfg = Config.TruckRobbery
local player = cache.ped
local streetName = 'Unknown'
local activeJob
local truckBlip
local routeBlip
local textUIContext

lib.onCache('ped', function(value)
    player = value
end)

local function hideText()
    if textUIContext then
        lib.hideTextUI()
        textUIContext = nil
    end
end

local function showText(text, opts)
    if textUIContext == text then return end
    lib.showTextUI(text, opts)
    textUIContext = text
end

local function createTruckBlip(coords)
    local mk = cfg.truckBlip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, mk.sprite)
    SetBlipColour(blip, mk.color)
    SetBlipDisplay(blip, mk.display)
    SetBlipScale(blip, mk.scale)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(mk.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function clearGuards(job)
    if not job or not job.guards then return end
    for i = #job.guards, 1, -1 do
        local ped = job.guards[i]
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        job.guards[i] = nil
    end
end

local function clearTruck(job)
    if not job then return end
    if DoesEntityExist(job.truckEntity) then
        DeleteEntity(job.truckEntity)
    end
    job.truckEntity = nil
    job.truckNet = nil
end

local function cleanupJob(aborted)
    if not activeJob then return end

    clearGuards(activeJob)
    clearTruck(activeJob)

    if DoesBlipExist(truckBlip) then
        RemoveBlip(truckBlip)
    end
    if DoesBlipExist(routeBlip) then
        RemoveBlip(routeBlip)
    end

    hideText()

    TriggerServerEvent('t1ger_truckrobbery:releaseJob', activeJob.id, activeJob.index, aborted)
    activeJob = nil
end

local function spawnTruck(job)
    if job.truckEntity and DoesEntityExist(job.truckEntity) then return end

    local spawn = job.spawn
    local pos = vector3(spawn.pos[1], spawn.pos[2], spawn.pos[3])
    local heading = spawn.heading or 0.0
    local model = LoadModel(cfg.truck.model)

    local veh = CreateVehicle(model, pos.x, pos.y, pos.z, heading, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleDoorsLockedForAllPlayers(veh, true)
    SetVehicleDoorShut(veh, 2, true)
    SetVehicleDoorShut(veh, 3, true)
    SetVehicleDoorShut(veh, 5, true)
    SetVehicleDoorShut(veh, 6, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehRadioStation(veh, 'OFF')

    job.truckEntity = veh
    job.truckNet = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdCanMigrate(job.truckNet, true)
    SetNetworkIdExistsOnAllMachines(job.truckNet, true)

    ReleaseModel(model)

    if DoesBlipExist(truckBlip) then
        RemoveBlip(truckBlip)
    end
    truckBlip = createTruckBlip(pos)
    SetBlipRoute(truckBlip, true)
    routeBlip = truckBlip

    job.guards = {}
    for _, guard in ipairs(spawn.security or {}) do
        local pedModel = LoadModel(guard.ped)
        local ped = CreatePedInsideVehicle(veh, 4, pedModel, guard.seat or -1, true, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, 1)
        SetPedCombatAbility(ped, 100)
        SetPedCombatMovement(ped, 2)
        SetPedCombatRange(ped, 2)
        SetPedKeepTask(ped, true)
        GiveWeaponToPed(ped, joaat(guard.weapon or 'WEAPON_SMG'), 250, false, true)
        SetPedArmour(ped, 100)
        SetPedAccuracy(ped, 60)
        SetEntityAsMissionEntity(ped, true, true)
        SetPedDropsWeaponsWhenDead(ped, false)
        SetPedRelationshipGroupHash(ped, `SECURITY_GUARD`)

        if guard.seat == -1 then
            TaskVehicleDriveWander(ped, veh, 40.0, 443)
        end
        job.guards[#job.guards + 1] = ped
        ReleaseModel(pedModel)
    end
end

local function guardsAlive(job)
    if not job.guards then return false end
    for _, ped in ipairs(job.guards) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            return true
        end
    end
    return false
end

local function notifyPolice()
    if not cfg.police.notify then return end
    local coords = GetEntityCoords(player)
    TriggerServerEvent('t1ger_truckrobbery:PoliceNotifySV', coords, streetName)
end

local function handleExplosion(job)
    if not job.truckEntity or not DoesEntityExist(job.truckEntity) then return end
    if not IsVehicleStopped(job.truckEntity) then
        NotifyPlayer('error', Lang.truck_not_stopped)
        return
    end

    local planting = lib.progressCircle({
        duration = 4500,
        position = 'bottom',
        label = Lang.progbar_plant_c4,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true, car = true }
    })

    if not planting then
        return
    end

    LoadAnim('anim@heists@ornate_bank@thermal_charge_heels')
    local coords = GetEntityCoords(player)
    local prop = CreateObject(joaat('prop_c4_final_green'), coords.x, coords.y, coords.z + 0.2, true, true, true)
    AttachEntityToEntity(prop, player, GetPedBoneIndex(player, 60309), 0.06, 0.0, 0.06, 90.0, 0.0, 0.0, true, true, false, true, 1, true)

    TaskPlayAnim(player, 'anim@heists@ornate_bank@thermal_charge_heels', 'thermal_charge', 3.0, -8.0, -1, 63, 0, false, false, false)
    FreezeEntityPosition(player, true)

    local detonation = lib.progressCircle({
        duration = cfg.rob.detonateTimer * 1000,
        position = 'bottom',
        label = Lang.progbar_detonating,
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, combat = true, car = true }
    })

    ClearPedTasks(player)
    FreezeEntityPosition(player, false)
    DetachEntity(prop, true, true)

    if not detonation then
        DeleteEntity(prop)
        return
    end

    notifyPolice()

    local bone = GetEntityBoneIndexByName(job.truckEntity, 'door_pside_r')
    local boneCoords = GetWorldPositionOfEntityBone(job.truckEntity, bone)
    SetVehicleDoorBroken(job.truckEntity, 2, false)
    SetVehicleDoorBroken(job.truckEntity, 3, false)
    AddExplosion(boneCoords.x, boneCoords.y, boneCoords.z, 2, 2.0, true, false, 1.0)
    DeleteEntity(prop)

    job.truckOpened = true
    TriggerServerEvent('t1ger_truckrobbery:updateStage', activeJob.id, 'truck_opened')
    NotifyPlayer('success', Lang.begin_to_rob)
end

local function handleRobbery(job)
    if not job.truckOpened then return end
    local pedCoords = GetEntityCoords(player)
    local vehicle = job.truckEntity
    local doorCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -3.0, 0.0)

    if #(pedCoords - doorCoords) > 2.0 then
        return
    end

    hideText()

    LoadAnim('anim@heists@ornate_bank@grab_cash_heels')
    local bagProp = CreateObject(joaat(cfg.rob.bagProp), pedCoords.x, pedCoords.y, pedCoords.z, true, true, true)
    AttachEntityToEntity(bagProp, player, GetPedBoneIndex(player, 57005), 0.0, 0.0, -0.16, 250.0, -30.0, 0.0, false, false, false, false, 2, true)
    TaskPlayAnim(player, 'anim@heists@ornate_bank@grab_cash_heels', 'grab', 8.0, -8.0, -1, 1, 0, false, false, false)

    local looting = lib.progressCircle({
        duration = cfg.rob.takeLootTimer * 1000,
        position = 'bottom',
        label = Lang.progbar_robbing,
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, combat = true, car = true }
    })

    DeleteEntity(bagProp)
    ClearPedTasks(player)

    if not looting then
        return
    end

    if cfg.rob.enableMoneyBag then
        SetPedComponentVariation(player, 5, 45, 0, 2)
    end

    local reward = lib.callback.await('t1ger_truckrobbery:claimReward', false, activeJob.id, activeJob.index)
    if not reward then
        NotifyPlayer('error', Lang.reward_error)
        return
    end

    if not reward.success then
        if reward.message then
            NotifyPlayer('error', reward.message)
        end
        return
    end

    if reward.message then
        NotifyPlayer('success', reward.message)
    end
    if reward.items then
        for _, itemMsg in ipairs(reward.items) do
            NotifyPlayer('inform', itemMsg)
        end
    end

    cleanupJob(false)
end

local function tickJob()
    while activeJob do
        local sleep = 1000
        local pedCoords = GetEntityCoords(player)
        if not DoesEntityExist(activeJob.truckEntity) then
            if #(pedCoords - activeJob.spawnCoords) <= cfg.truck.spawnTrigger then
                spawnTruck(activeJob)
            end
        else
            if not DoesBlipExist(truckBlip) then
                truckBlip = createTruckBlip(GetEntityCoords(activeJob.truckEntity))
                SetBlipRoute(truckBlip, true)
                routeBlip = truckBlip
            end

            local truckCoords = GetEntityCoords(activeJob.truckEntity)
            local distance = #(pedCoords - truckCoords)
            sleep = distance < 80.0 and 250 or 1000

            if distance <= cfg.truck.spawnDistance then
                if guardsAlive(activeJob) then
                    if distance <= 30.0 then
                        showText(Lang.kill_the_guards, { icon = 'fa-solid fa-gun' })
                    else
                        hideText()
                    end
                else
                    if not activeJob.truckOpened then
                        showText(('[G] %s'):format(Lang.open_truck_door), { icon = 'fa-solid fa-bomb' })
                        if IsControlJustReleased(0, 47) then
                            hideText()
                            handleExplosion(activeJob)
                        end
                    else
                        showText(('[E] %s'):format(Lang.rob_the_truck), { icon = 'fa-solid fa-sack-dollar' })
                        if IsControlJustReleased(0, 38) then
                            handleRobbery(activeJob)
                        end
                    end
                end
            else
                hideText()
            end

            if distance >= cfg.truck.maxPursuitDistance then
                NotifyPlayer('error', 'You moved too far away from the truck.')
                cleanupJob(true)
            end
        end

        Wait(sleep)
    end
    hideText()
end

local function startJob(data)
    local spawn = data.spawn
    activeJob = {
        id = data.id,
        index = data.index,
        spawn = spawn,
        spawnCoords = vector3(spawn.pos[1], spawn.pos[2], spawn.pos[3]),
        truckEntity = nil,
        truckOpened = false,
        guards = {}
    }
    if DoesBlipExist(truckBlip) then RemoveBlip(truckBlip) end
    if DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end

    truckBlip = createTruckBlip(activeJob.spawnCoords)
    SetBlipRoute(truckBlip, true)
    routeBlip = truckBlip

    SetNewWaypoint(activeJob.spawnCoords.x, activeJob.spawnCoords.y)

    NotifyPlayer('inform', Lang.job_started)

    CreateThread(tickJob)
end

local function attemptHack()
    if activeJob then return end
    local computer = cfg.computer
    local coords = vector3(computer.pos[1], computer.pos[2], computer.pos[3])
    TaskTurnPedToFaceCoord(player, coords.x, coords.y, coords.z, 1000)
    Wait(750)
    SetEntityHeading(player, computer.heading or GetEntityHeading(player))
    LoadAnim(computer.animation.dict)
    TaskPlayAnim(player, computer.animation.dict, computer.animation.clip, 1.0, 1.0, -1, computer.animation.flag or 0, 0, false, false, false)
    FreezeEntityPosition(player, true)

    local success
    if computer.hack.useSkillCheck then
        success = lib.skillCheck(computer.hack.sequence, { '1', '2', '3', '4' })
    else
        success = lib.progressCircle({
            duration = computer.hack.fallbackDuration or 4000,
            position = 'bottom',
            label = Lang.progbar_hacking,
            useWhileDead = false,
            canCancel = false,
            disable = { move = true, combat = true, car = true }
        })
    end

    ClearPedTasks(player)
    FreezeEntityPosition(player, false)

    if not success then
        NotifyPlayer('error', Lang.hacking_failed)
        return
    end

    local response = lib.callback.await('t1ger_truckrobbery:requestJob', false)
    if not response then
        NotifyPlayer('error', 'Unable to start the job right now.')
        return
    end

    if not response.success then
        NotifyPlayer('error', response.reason or 'Job unavailable.')
        return
    end

    startJob(response.job)
end

local startPoint = lib.points.new({
    coords = vector3(cfg.computer.pos[1], cfg.computer.pos[2], cfg.computer.pos[3]),
    distance = 25.0,
    onEnter = function(self)
        self.prompt = false
    end,
    onExit = function(self)
        hideText()
        self.prompt = false
    end,
    nearby = function(self)
        if activeJob then
            if self.prompt then
                hideText()
                self.prompt = false
            end
            return
        end

        if self.currentDistance <= 2.0 then
            if not self.prompt then
                showText(('[E] %s'):format(Lang.job_draw_text), { icon = cfg.computer.prompt.icon })
                self.prompt = true
            end

            if IsControlJustReleased(0, 38) then
                hideText()
                attemptHack()
            end
        elseif self.prompt then
            hideText()
            self.prompt = false
        end
    end
})

CreateThread(function()
    while true do
        local coords = GetEntityCoords(player)
        local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        streetName = GetStreetNameFromHashKey(streetHash)
        Wait(3000)
    end
end)

RegisterNetEvent('t1ger_truckrobbery:PoliceNotifyCL', function(alert)
    if not PlayerIsCop() then return end
    NotifyPlayer('inform', ('%s: %s'):format(Lang.dispatch_name, alert))
end)

RegisterNetEvent('t1ger_truckrobbery:PoliceNotifyBlip', function(targetCoords)
    if not PlayerIsCop() then return end
    local cfgPolice = cfg.police
    if not cfgPolice.blip.show then return end
    local alpha = cfgPolice.blip.alpha
    local blip = AddBlipForRadius(targetCoords.x, targetCoords.y, targetCoords.z, cfgPolice.blip.radius)
    SetBlipHighDetail(blip, true)
    SetBlipColour(blip, cfgPolice.blip.color)
    SetBlipAlpha(blip, alpha)
    SetBlipAsShortRange(blip, true)

    CreateThread(function()
        while alpha > 0 do
            Wait(cfgPolice.blip.time * 4)
            alpha = alpha - 1
            SetBlipAlpha(blip, alpha)
        end
        RemoveBlip(blip)
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    cleanupJob(true)
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    cleanupJob(true)
end)
