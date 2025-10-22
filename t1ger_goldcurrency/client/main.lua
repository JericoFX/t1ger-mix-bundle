-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports['qb-core']:GetCoreObject()

local function getPlayerPed()
    return cache.ped
end

local function getPlayerCoords()
    local ped = getPlayerPed()
    if ped and DoesEntityExist(ped) then
        return GetEntityCoords(ped)
    end
    return vec3(0.0, 0.0, 0.0)
end

-- Forward declarations
local RequestJobFromNPC
local OpenJobContext
local OpenSmeltingFunction
local OpenGoldExchangeFunction

-- Job Config Data:
RegisterNetEvent('t1ger_goldcurrency:updateConfigCL')
AddEventHandler('t1ger_goldcurrency:updateConfigCL',function(data)
    Config.GoldJobs = data
end)

local NPC = nil
local NPC_blip = nil
local jobTargetRegistered = false
local jobPoint, deliveryPoint
local smelteryZones = {}
local exchangeZones = {}
local smelteryPoints = {}
local exchangePoints = {}

local function removeNpcTarget()
    if NPC and jobTargetRegistered then
        exports.ox_target:removeLocalEntity(NPC)
        jobTargetRegistered = false
    end
end

local function removeJobPoint()
    if jobPoint then
        jobPoint:remove()
        jobPoint = nil
    end
end

local function removeDeliveryPoint()
    if deliveryPoint then
        deliveryPoint:remove()
        deliveryPoint = nil
    end
end

local function addNpcTarget()
    if not NPC or not DoesEntityExist(NPC) then return end
    removeNpcTarget()
    exports.ox_target:addLocalEntity(NPC, {
        {
            name = 't1ger_goldcurrency:job_npc',
            icon = Config.JobNPC.targetIcon or 'fa-solid fa-sack-dollar',
            label = Config.JobNPC.targetLabel or Lang['target_gold_job'],
            onSelect = function()
                OpenJobContext()
            end
        }
    })
    jobTargetRegistered = true
end

RegisterNetEvent('t1ger_goldcurrency:createNPC')
AddEventHandler('t1ger_goldcurrency:createNPC', function(data)
    if NPC ~= nil then
        removeNpcTarget()
        DeleteEntity(NPC)
        NPC = nil
    end
    CreateJobNPC(data)
end)

-- Get Available Gold Job
function GetAvailableGoldJob(fees)
    local id = math.random(1, #Config.GoldJobs)
    local i = 0
    while Config.GoldJobs[id].inUse and i < 100 do
        i = i + 1
        id = math.random(1, #Config.GoldJobs)
    end
    if i == 100 then
        ShowNotify(Lang['no_jobs_available'], 'error')
    else
        Config.GoldJobs[id].inUse = true
        TriggerServerEvent('t1ger_goldcurrency:updateConfigSV', Config.GoldJobs)
        local ran_veh = math.random(1, #Config.JobVehicles)
        local veh_model = Config.JobVehicles[ran_veh]
        TriggerServerEvent('t1ger_goldcurrency:prepareJobSV', id, fees, veh_model)
    end
end

-- Request Job From NPC:
local interacting = false
RequestJobFromNPC = function()
    local cooldown = lib.callback.await('t1ger_goldcurrency:getJobCooldown', false)
    if cooldown then
        interacting = false
        return
    end

    local ped = getPlayerPed()
    if not ped then
        interacting = false
        return
    end

    local anim = {dict = 'missheistdockssetup1ig_5@base', lib = 'workers_talking_base_dockworker1'}
    LoadAnim(anim.dict)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, anim.dict, anim.lib, 3.0, 0.5, -1, 31, 1.0, 0, 0)

    local progress = true
    if Config.ProgressBars then
        progress = lib.progressCircle({
            duration = Config.JobNPC.talkSeconds * 1000,
            label = Lang['pb_talking'],
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {move = true, car = true, combat = true}
        })
    else
        Wait(Config.JobNPC.talkSeconds * 1000)
    end

    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    if not progress then
        interacting = false
        return
    end

    local hasMoney = lib.callback.await('t1ger_goldcurrency:getJobFees', false, Config.JobNPC.jobFees)
    if not hasMoney then
        ShowNotify(Lang['not_enough_money'], 'error')
        interacting = false
        return
    end

    local copsOnline = lib.callback.await('t1ger_goldcurrency:checkCops', false)
    if not copsOnline then
        ShowNotify(Lang['not_enough_cops'], 'error')
        interacting = false
        return
    end

    GetAvailableGoldJob(Config.JobNPC.jobFees)
    interacting = false
end

OpenJobContext = function()
    if interacting then return end
    lib.registerContext({
        id = 't1ger_goldcurrency_job_menu',
        title = Lang['job_menu_title'],
        options = {
            {
                title = Lang['job_menu_start'],
                description = Lang['job_menu_cost']:format(Config.JobNPC.jobFees.amount or 0),
                icon = Config.JobNPC.targetIcon or 'fa-solid fa-sack-dollar',
                onSelect = function()
                    if interacting then return end
                    interacting = true
                    RequestJobFromNPC()
                end
            },
            {
                title = Lang['menu_close'],
                icon = 'fa-solid fa-xmark',
                close = true,
                onSelect = function()
                    interacting = false
                end
            }
        }
    })
    lib.showContext('t1ger_goldcurrency_job_menu')
end

-- Event for Gold Job:
local job_veh = nil
local job_goons = {}
local veh_lockpicked = false
local job_end = false
local job_blip = nil
local currentJobId = nil

local function resetJobEntities()
    removeJobPoint()
    removeDeliveryPoint()
    if DoesEntityExist(job_veh) then
        DeleteVehicle(job_veh)
    end
    job_veh = nil
    for _, ped in pairs(job_goons) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    job_goons = {}
    veh_lockpicked = false
    if DoesBlipExist(job_blip) then
        RemoveBlip(job_blip)
    end
    job_blip = nil
end

local function finalizeJob(messageKey, messageType)
    if currentJobId and Config.GoldJobs[currentJobId] then
        Config.GoldJobs[currentJobId].inUse = false
        TriggerServerEvent('t1ger_goldcurrency:updateConfigSV', Config.GoldJobs)
    end
    if messageKey and Lang[messageKey] then
        ShowNotify(Lang[messageKey], messageType or 'inform')
    end
    resetJobEntities()
    job_end = false
    currentJobId = nil
end

local function handleJobFailure(messageKey)
    job_end = true
    finalizeJob(messageKey, 'error')
end

local function setupDeliveryPoint(delivery, veh_model)
    if deliveryPoint or not delivery then return end
    if Config.UsePhoneMSG then
        JobNotifyMSG(Lang['deliver_veh_msg'])
    else
        ShowNotify(Lang['deliver_veh_msg'])
    end
    if job_blip and DoesBlipExist(job_blip) then
        RemoveBlip(job_blip)
    end
    job_blip = AddBlipForCoord(delivery.pos[1], delivery.pos[2], delivery.pos[3])
    SetBlipSprite(job_blip, delivery.blip.sprite)
    SetBlipColour(job_blip, delivery.blip.color)
    SetBlipRoute(job_blip, delivery.blip.route)
    SetBlipRouteColour(job_blip, delivery.blip.color)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(delivery.blip.label)
    EndTextCommandSetBlipName(job_blip)

    deliveryPoint = lib.points.new({
        coords = vec3(delivery.pos[1], delivery.pos[2], delivery.pos[3]),
        distance = delivery.marker.drawDist or 20.0,
        nearby = function(point)
            if job_end then
                point:remove()
                return
            end

            if not DoesEntityExist(job_veh) then
                handleJobFailure('veh_is_taken')
                point:remove()
                return
            end

            local ped = getPlayerPed()
            if not ped then
                point:wait(500)
                return
            end

            local pedCoords = GetEntityCoords(ped)
            local distance = #(pedCoords - point.coords)
            local mk = delivery.marker or {}

            if mk.enable and distance <= (mk.drawDist or 20.0) then
                local scale = mk.scale or vec3(2.0, 2.0, 1.0)
                DrawMarker(mk.type or 1, delivery.pos[1], delivery.pos[2], delivery.pos[3]-0.97, 0, 0, 0, 180.0, 0, 0, scale.x or 2.0, scale.y or 2.0, scale.z or 1.0, mk.color and mk.color.r or 255, mk.color and mk.color.g or 255, mk.color and mk.color.b or 255, mk.color and mk.color.a or 120, false, true, 2, false, false, false, false)
            end

            if distance < 2.0 and GetVehiclePedIsIn(ped, false) == job_veh and GetEntityModel(job_veh) == GetHashKey(veh_model) then
                DrawText3Ds(delivery.pos[1], delivery.pos[2], delivery.pos[3], Lang['press_to_deliver'])
                if IsControlJustPressed(0, 38) then
                    if DoesBlipExist(job_blip) then RemoveBlip(job_blip) end
                    SetVehicleForwardSpeed(job_veh, 0)
                    SetVehicleEngineOn(job_veh, false, false, true)
                    if IsPedInAnyVehicle(ped, true) then
                        TaskLeaveVehicle(ped, job_veh, 4160)
                        SetVehicleDoorsLockedForAllPlayers(job_veh, true)
                    end
                    Wait(700)
                    FreezeEntityPosition(job_veh, true)
                    TriggerServerEvent('t1ger_goldcurrency:giveJobReward')
                    finalizeJob(nil, 'success')
                    point:remove()
                end
            end

            point:wait(0)
        end
    })
end

RegisterNetEvent('t1ger_goldcurrency:startTheGoldJob')
AddEventHandler('t1ger_goldcurrency:startTheGoldJob', function(id, veh_model)
    interacting = false
    job_end = false
    veh_lockpicked = false
    resetJobEntities()

    local cfg = Config.GoldJobs[id]
    if not cfg then
        ShowNotify(Lang['no_jobs_available'], 'error')
        return
    end

    currentJobId = id

    if Config.UsePhoneMSG then
        JobNotifyMSG(Lang['go_to_the_location'])
    else
        ShowNotify(Lang['go_to_the_location'])
    end

    job_blip = CreateJobBlip(cfg)

    local veh_spawned, goons_spawned, job_player = false, false, false
    local delivery = Config.Delivery

    jobPoint = lib.points.new({
        coords = vec3(cfg.pos[1], cfg.pos[2], cfg.pos[3]),
        distance = 200.0,
        nearby = function(point)
            if job_end then
                point:remove()
                return
            end

            if not cfg.inUse then
                finalizeJob(nil)
                point:remove()
                return
            end

            local ped = getPlayerPed()
            if not ped or not DoesEntityExist(ped) then
                point:wait(500)
                return
            end

            local pedCoords = GetEntityCoords(ped)
            local distance = #(pedCoords - point.coords)

            if distance < 120.0 and not veh_spawned then
                ClearAreaOfVehicles(cfg.pos[1], cfg.pos[2], cfg.pos[3], 10.0, false, false, false, false, false)
                job_veh = CreateJobVehicle(veh_model, cfg.pos)
                veh_spawned = true
            end

            if distance < 120.0 and not goons_spawned then
                ClearAreaOfPeds(cfg.pos[1], cfg.pos[2], cfg.pos[3], 10.0, 1)
                SetPedRelationshipGroupHash(ped, GetHashKey("PLAYER"))
                AddRelationshipGroup('JobNPCs')
                for i = 1, #cfg.goons do
                    job_goons[i] = CreateJobPed(cfg.goons[i])
                end
                goons_spawned = true
            end

            if distance < 60.0 and goons_spawned and not job_player then
                SetPedRelationshipGroupHash(ped, GetHashKey("PLAYER"))
                AddRelationshipGroup('JobNPCs')
                for i = 1, #job_goons do
                    ClearPedTasksImmediately(job_goons[i])
                    TaskCombatPed(job_goons[i], ped, 0, 16)
                    SetPedFleeAttributes(job_goons[i], 0, false)
                    SetPedCombatAttributes(job_goons[i], 5, true)
                    SetPedCombatAttributes(job_goons[i], 16, true)
                    SetPedCombatAttributes(job_goons[i], 46, true)
                    SetPedCombatAttributes(job_goons[i], 26, true)
                    SetPedSeeingRange(job_goons[i], 75.0)
                    SetPedHearingRange(job_goons[i], 50.0)
                    SetPedEnableWeaponBlocking(job_goons[i], true)
                end
                SetRelationshipBetweenGroups(0, GetHashKey("JobNPCs"), GetHashKey("JobNPCs"))
                SetRelationshipBetweenGroups(5, GetHashKey("JobNPCs"), GetHashKey("PLAYER"))
                SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey("JobNPCs"))
                job_player = true
            end

            if veh_spawned and DoesEntityExist(job_veh) then
                local veh_pos = GetEntityCoords(job_veh)
                local veh_dist = #(pedCoords - veh_pos)
                if veh_dist < 2.5 and not veh_lockpicked then
                    DrawText3Ds(veh_pos.x, veh_pos.y, veh_pos.z, Lang['press_to_lockpick'])
                    if IsControlJustPressed(0, 47) then
                        LockpickJobVehicle()
                    end
                end
            end

            if veh_lockpicked and DoesEntityExist(job_veh) then
                if IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) == job_veh then
                    if DoesBlipExist(job_blip) then
                        RemoveBlip(job_blip)
                        job_blip = nil
                    end
                    setupDeliveryPoint(delivery, veh_model)
                end
            end

            if veh_spawned and not DoesEntityExist(job_veh) then
                handleJobFailure('veh_is_taken')
                point:remove()
                return
            end

            if veh_lockpicked and DoesEntityExist(job_veh) then
                local veh_pos = GetEntityCoords(job_veh)
                if #(pedCoords - veh_pos) > 50.0 then
                    handleJobFailure('too_far_from_veh')
                    point:remove()
                    return
                end
            end

            point:wait(distance > 150.0 and 750 or 0)
        end,
        onExit = function()
            if not job_end and veh_lockpicked then
                handleJobFailure('too_far_from_veh')
            end
        end
    })
end)

-- Lockpick Job Vehicle:
function LockpickJobVehicle()
    -- Police Alert:
    if Config.PoliceSettings.enableAlert then AlertPoliceFunction() end
    -- Player Animation
    local anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', lib = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'}
    local ped = getPlayerPed()
    if not ped or not job_veh or not DoesEntityExist(job_veh) then return end
    LoadAnim(anim.dict)
    SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"),true)
    Wait(250)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, anim.dict, anim.lib, 3.0, -8, -1, 63, 0, 0, 0, 0 )
    local progress = true
    if Config.ProgressBars then
        progress = lib.progressCircle({
            duration = 7500,
            label = Lang['pb_lockpicking'],
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {move = true, car = true, combat = true}
        })
    else
        Wait(7500)
    end
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    if not progress then return end
    veh_lockpicked = true
    SetVehicleDoorsLockedForAllPlayers(job_veh, false)
    ShowNotify(Lang['vehicle_lockpicked'], 'success')
end

-- Function to create job vehicle:
function CreateJobVehicle(model, pos)
    LoadModel(model)
    local vehicle = CreateVehicle(model, pos[1], pos[2], pos[3], pos[4], true, false)
    NetworkRegisterEntityAsNetworked(vehicle)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(vehicle), true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(vehicle), true)
    SetVehicleNeedsToBeHotwired(vehicle, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleDoorsLockedForAllPlayers(vehicle, true)
    SetVehicleIsStolen(vehicle, false)
    SetVehicleIsWanted(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleFuelLevel(vehicle, 80.0)
    DecorSetFloat(vehicle, "_FUEL_LEVEL", GetVehicleFuelLevel(vehicle))
    SetVehicleOnGroundProperly(vehicle)
    return vehicle
end

-- Function to create job ped(s):
function CreateJobPed(goon)
    LoadModel(goon.ped)
    local goonNPC = CreatePed(4, GetHashKey(goon.ped), goon.pos[1], goon.pos[2], goon.pos[3], goon.pos[4], false, true)
    NetworkRegisterEntityAsNetworked(goonNPC)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(goonNPC), true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(goonNPC), true)
    SetPedCanSwitchWeapon(goonNPC, true)
    SetEntityInvincible(goonNPC, false)
    SetEntityVisible(goonNPC, true)
    SetEntityAsMissionEntity(goonNPC)
    LoadAnim(goon.anim.dict)
    TaskPlayAnim(goonNPC, goon.anim.dict, goon.anim.lib, 8.0, -8, -1, 49, 0, 0, 0, 0)
    GiveWeaponToPed(goonNPC, GetHashKey(goon.weapon), 255, false, false)
    SetPedDropsWeaponsWhenDead(goonNPC, false)
    SetPedCombatAttributes(goonNPC, false)
    SetPedFleeAttributes(goonNPC, 0, false)
    SetPedEnableWeaponBlocking(goonNPC, true)
    SetPedRelationshipGroupHash(goonNPC, GetHashKey("JobNPCs"))
    TaskGuardCurrentPosition(goonNPC, 15.0, 15.0, 1)
    return goonNPC
end

function CreateJobBlip(cfg)
    local blip = AddBlipForCoord(cfg.pos[1], cfg.pos[2], cfg.pos[3])
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Gold Job')
    EndTextCommandSetBlipName(blip)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)
    return blip
end

-- Create Job NPC:
function CreateJobNPC(data)
    LoadModel(data.ped)
    NPC = CreatePed(7, GetHashKey(data.ped), data.pos[1], data.pos[2], data.pos[3]-0.97, data.pos[4], 0, true, true)
    FreezeEntityPosition(NPC, true)
    SetBlockingOfNonTemporaryEvents(NPC, true)
    TaskStartScenarioInPlace(NPC, data.scenario, 0, false)
    SetEntityInvincible(NPC, true)
    SetEntityAsMissionEntity(NPC, true)
    addNpcTarget()
    -- Create Blip
    CreateBlipForNPC(NPC, data.blip)
end

-- Create NPC Blip:
function CreateBlipForNPC(entity, blip)
    if DoesBlipExist(NPC_blip) then
        RemoveBlip(NPC_blip)
    end
    local pos = GetEntityCoords(entity)
    if blip.enable then
        CreateThread(function()
            NPC_blip = AddBlipForCoord(pos[1], pos[2], pos[3])
            SetBlipSprite (NPC_blip, blip.sprite)
            SetBlipDisplay(NPC_blip, 4)
            SetBlipScale  (NPC_blip, blip.scale)
            SetBlipColour (NPC_blip, blip.color)
            SetBlipAsShortRange(NPC_blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(blip.str)
            EndTextCommandSetBlipName(NPC_blip)
        end)
    end
end

AddEventHandler('baseevents:onPlayerDied', function()
    if currentJobId then
        handleJobFailure('cancel_job')
    end
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    if currentJobId then
        handleJobFailure('cancel_job')
    end
end)

RegisterCommand('gold_cancel', function()
    if currentJobId then
        handleJobFailure('cancel_job')
    else
        ShowNotify(Lang['cancel_job'], 'error')
    end
end, false)

-- ## [[ SMELTERY SECTION ]] ## --

local plySmelting = false

-- Function to smelt gold:
OpenSmeltingFunction = function()
    if plySmelting then return end
    plySmelting = true

    local removed = lib.callback.await('t1ger_goldcurrency:removeItem', false, Config.DatabaseItems['goldwatch'], Config.SmelterySettings.input)
    if not removed then
        ShowNotify(Lang['not_enough_watches'], 'error')
        plySmelting = false
        return
    end

    local ped = getPlayerPed()
    if not ped then
        TriggerServerEvent('t1ger_goldcurrency:giveItem', Config.DatabaseItems['goldwatch'], Config.SmelterySettings.input)
        plySmelting = false
        return
    end

    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'))
    Wait(200)

    TaskStartScenarioInPlace(ped, "PROP_HUMAN_BUM_BIN", 0, true)
    local progress = true
    if Config.ProgressBars then
        progress = lib.progressCircle({
            duration = (Config.SmelterySettings.time * 1000),
            label = Lang['pb_smelting'],
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {move = true, car = true, combat = true}
        })
    else
        Wait((Config.SmelterySettings.time * 1000))
    end

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    if not progress then
        TriggerServerEvent('t1ger_goldcurrency:giveItem', Config.DatabaseItems['goldwatch'], Config.SmelterySettings.input)
        plySmelting = false
        return
    end

    local amount = Config.SmelterySettings.output
    local itemAdded = lib.callback.await('t1ger_goldcurrency:addItem', false, Config.DatabaseItems['goldbar'], amount)
    if not itemAdded then
        TriggerServerEvent('t1ger_goldcurrency:giveItem', Config.DatabaseItems['goldwatch'], Config.SmelterySettings.input)
    end
    plySmelting = false
end

-- Create Smeltery Blip:
CreateThread(function()
    for _,v in pairs(Config.Smeltery) do
        local bp = v.blip
        if bp.enable then
            local blip = AddBlipForCoord(v.pos[1], v.pos[2], v.pos[3])
            SetBlipSprite(blip, bp.sprite)
            SetBlipDisplay(blip, bp.display)
            SetBlipScale  (blip, bp.scale)
            SetBlipColour (blip, bp.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(bp.str)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ## [[ EXCHANGE SECTION ]] ## --

local plyExchanging = false

-- Function to exchange gold:
OpenGoldExchangeFunction = function()
    if plyExchanging then return end
    plyExchanging = true

    local cooldown = lib.callback.await('t1ger_goldcurrency:getExchangeCooldown', false)
    if cooldown then
        plyExchanging = false
        return
    end

    local removed = lib.callback.await('t1ger_goldcurrency:removeItem', false, Config.DatabaseItems['goldbar'], Config.ExchangeSettings.input)
    if not removed then
        ShowNotify(Lang['not_enough_goldbar'], 'error')
        plyExchanging = false
        return
    end

    local ped = getPlayerPed()
    if not ped then
        TriggerServerEvent('t1ger_goldcurrency:giveItem', Config.DatabaseItems['goldbar'], Config.ExchangeSettings.input)
        plyExchanging = false
        return
    end

    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'))
    Wait(200)

    local progress = true
    if Config.ProgressBars then
        progress = lib.progressCircle({
            duration = (Config.ExchangeSettings.time * 1000),
            label = Lang['pb_exchanging'],
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {move = true, car = true, combat = true}
        })
    else
        Wait((Config.ExchangeSettings.time * 1000))
    end

    FreezeEntityPosition(ped, false)

    if not progress then
        TriggerServerEvent('t1ger_goldcurrency:giveItem', Config.DatabaseItems['goldbar'], Config.ExchangeSettings.input)
        plyExchanging = false
        return
    end

    local amount = Config.ExchangeSettings.money.amount
    TriggerServerEvent('t1ger_goldcurrency:giveExchangeReward', amount, Config.ExchangeSettings.money.account)
    TriggerServerEvent('t1ger_goldcurrency:addExchangeCooldown')
    plyExchanging = false
end

-- Create Exchange Blip:
CreateThread(function()
    for _,v in pairs(Config.Exchange) do
        local bp = v.blip
        if bp.enable then
            local blip = AddBlipForCoord(v.pos[1], v.pos[2], v.pos[3])
            SetBlipSprite(blip, bp.sprite)
            SetBlipDisplay(blip, bp.display)
            SetBlipScale  (blip, bp.scale)
            SetBlipColour (blip, bp.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(bp.str)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Target registrations
CreateThread(function()
    for index, data in pairs(Config.Smeltery) do
        if data.marker and data.marker.enable then
            local mk = data.marker
            smelteryPoints[#smelteryPoints + 1] = lib.points.new({
                coords = vec3(data.pos[1], data.pos[2], data.pos[3]),
                distance = mk.drawDist or 10.0,
                nearby = function(point)
                    if mk.enable then
                        local scale = mk.scale or vec3(2.0, 2.0, 1.0)
                        DrawMarker(mk.type or 1, data.pos[1], data.pos[2], data.pos[3] - 0.975, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale.x or 2.0, scale.y or 2.0, scale.z or 1.0, mk.color and mk.color.r or 255, mk.color and mk.color.g or 255, mk.color and mk.color.b or 255, mk.color and mk.color.a or 120, false, true, 2, false, false, false, false)
                    end
                    point:wait(0)
                end
            })
        end

        smelteryZones[#smelteryZones + 1] = exports.ox_target:addSphereZone({
            coords = vec3(data.pos[1], data.pos[2], data.pos[3]),
            radius = data.targetRadius or 1.5,
            debug = false,
            options = {
                {
                    name = ('t1ger_goldcurrency:smelt_%s'):format(index),
                    icon = data.targetIcon or 'fa-solid fa-fire',
                    label = data.targetLabel or Lang['target_smeltery'],
                    onSelect = function()
                        OpenSmeltingFunction()
                    end
                }
            }
        })
    end

    for index, data in pairs(Config.Exchange) do
        if data.marker and data.marker.enable then
            local mk = data.marker
            exchangePoints[#exchangePoints + 1] = lib.points.new({
                coords = vec3(data.pos[1], data.pos[2], data.pos[3]),
                distance = mk.drawDist or 10.0,
                nearby = function(point)
                    if mk.enable then
                        local scale = mk.scale or vec3(2.0, 2.0, 1.0)
                        DrawMarker(mk.type or 1, data.pos[1], data.pos[2], data.pos[3] - 0.975, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale.x or 2.0, scale.y or 2.0, scale.z or 1.0, mk.color and mk.color.r or 255, mk.color and mk.color.g or 255, mk.color and mk.color.b or 255, mk.color and mk.color.a or 120, false, true, 2, false, false, false, false)
                    end
                    point:wait(0)
                end
            })
        end

        exchangeZones[#exchangeZones + 1] = exports.ox_target:addSphereZone({
            coords = vec3(data.pos[1], data.pos[2], data.pos[3]),
            radius = data.targetRadius or 1.25,
            debug = false,
            options = {
                {
                    name = ('t1ger_goldcurrency:exchange_%s'):format(index),
                    icon = data.targetIcon or 'fa-solid fa-scale-balanced',
                    label = data.targetLabel or Lang['target_exchange'],
                    onSelect = function()
                        OpenGoldExchangeFunction()
                    end
                }
            }
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeNpcTarget()
    removeJobPoint()
    removeDeliveryPoint()
    for _, zone in pairs(smelteryZones) do
        exports.ox_target:removeZone(zone)
    end
    for _, zone in pairs(exchangeZones) do
        exports.ox_target:removeZone(zone)
    end
    for _, point in pairs(smelteryPoints) do
        point:remove()
    end
    for _, point in pairs(exchangePoints) do
        point:remove()
    end
    resetJobEntities()
end)
