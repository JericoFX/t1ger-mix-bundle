-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------
player = nil
coords = {}
ply_veh = nil

CreateThread(function()
    while true do
        player = PlayerPedId()
        coords = GetEntityCoords(player)
        if IsPedInAnyVehicle(player, false) then
            ply_veh = GetVehiclePedIsIn(player, false)
        else
            ply_veh = nil
        end
        Wait(500)
    end
end)

RegisterCommand(Config.Command, function()
    if IsPlayerJobCop() then
        TrafficPolicerMenu()
    end
end, false)

CreateThread(function()
    while true do
        Wait(1)
        if IsControlJustPressed(0, Config.Keybind) and IsPlayerJobCop() then
            TrafficPolicerMenu()
        end
    end
end)

local function plateText(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+', '')
end

function TrafficPolicerMenu()
    local options = {
        {
            title = Lang['person_lookup'],
            icon = 'fa-solid fa-id-card',
            onSelect = LookupClosestPlayer
        },
        {
            title = Lang['plate_lookup'],
            icon = 'fa-solid fa-car',
            onSelect = LookupClosestVehicle
        },
        {
            title = Lang['impound_vehicle'],
            icon = 'fa-solid fa-car-burst',
            onSelect = ImpoundClosestVehicle
        },
        {
            title = Lang['unlock_vehicle'],
            icon = 'fa-solid fa-key',
            onSelect = UnlockClosestVehicle
        },
        {
            title = Lang['issue_citation'],
            icon = 'fa-solid fa-ticket',
            onSelect = OpenCitationMain
        },
        {
            title = Lang['breathalyzer_test'],
            icon = 'fa-solid fa-wine-bottle',
            onSelect = BreathalyzerTest
        },
        {
            title = Lang['drug_swap_test'],
            icon = 'fa-solid fa-syringe',
            onSelect = DrugSwabTest
        }
    }

    if Config.T1GER_Garage then
        options[#options + 1] = {
            title = Lang['seize_vehicle'],
            icon = 'fa-solid fa-warehouse',
            onSelect = SeizeClosestVehicle
        }
    end

    if Config.SpeedDetection.enable then
        options[#options + 1] = {
            title = Lang['speed_detection'],
            icon = 'fa-solid fa-gauge-high',
            onSelect = ToggleSpeedTrap
        }
    end

    if Config.BarricadeSystem then
        options[#options + 1] = {
            title = Lang['barricade_menu'],
            icon = 'fa-solid fa-road-barrier',
            onSelect = function()
                TriggerEvent('marcusbarricade:openMenu')
            end
        }
    end

    lib.registerContext({
        id = 'traffic_policer_main',
        title = Lang['menu_main_title'],
        options = options
    })

    lib.showContext('traffic_policer_main')
end

function LookupClosestPlayer()
    local target = GetClosestPlayer()
    if not target then return end

   local cfg = Config.PlayerLookup
   local serverId = GetPlayerServerId(target)
    local targetName = GetPlayerName(target) or 'Player'
    TriggerEvent('t1ger_trafficpolicer:notify', (Lang['ply_lookup_request']):format(targetName, '...'))
    PlayRadioSound()
    Wait(750)
    TriggerEvent('t1ger_trafficpolicer:notify', Lang['ply_lookup_reply'])
    PlayRadioSound()

    local data = lib.callback.await('t1ger_trafficpolicer:lookupPlayer', false, serverId)
    if not data then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['ply_not_found'], 'error')
        return
    end

    Wait(cfg.delay * 1000)

    local sex = 'Male'
    if data.sex == 'F' or data.sex == 'f' or data.sex == 1 then
        sex = 'Female'
    end
    local license = Lang['license_invalid']
    if Config.UseQBLicenses and data.license then
        license = Lang['license_valid']
    end

    local message = (Lang['ply_lookup_result']):format((data.firstname .. ' ' .. data.lastname), sex, data.dob)
    lib.alertDialog({
        header = cfg.notify.title,
        content = message,
        centered = true,
        cancel = false
    })

    if Config.UseQBLicenses then
        TriggerEvent('t1ger_trafficpolicer:notify', (Lang['license_status']):format(license))
    end
    PlayRadioSound()
end

function LookupClosestVehicle()
    local cfg = Config.PlateLookup
    local coordA = GetEntityCoords(player, true)
    local coordB = GetOffsetFromEntityInWorldCoords(player, 0.0, cfg.dist, 0.0)
    local targetVeh = GetVehicleInDirection(coordA, coordB, Config.SpeedDetection.raycastRadius)

    if not (DoesEntityExist(targetVeh) and IsEntityAVehicle(targetVeh)) then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['plate_not_readed'], 'error')
        return
    end

    local plate = plateText(targetVeh)
    local vehLabel = GetVehName(targetVeh)

    TriggerEvent('t1ger_trafficpolicer:notify', (Lang['plate_lookup_request']):format(vehLabel, plate))
    PlayRadioSound()
    Wait(750)
    TriggerEvent('t1ger_trafficpolicer:notify', Lang['plate_lookup_reply'])
    PlayRadioSound()

    local ownerTxt, insuranceText = '', Lang['insurance_no']
    local data = lib.callback.await('t1ger_trafficpolicer:lookupPlate', false, plate)
    if data then
        if Config.T1GER_Insurance and data.insurance ~= nil then
            insuranceText = data.insurance and Lang['insurance_yes'] or Lang['insurance_no']
        end
        ownerTxt = string.format('%s %s, dob: %s', data.firstname, data.lastname, data.dob)
    else
        math.randomseed(GetGameTimer())
        local chance = math.random(0, 100)
        if chance < cfg.npc_veh.chance then
            ownerTxt = cfg.npc_veh.unreg
        else
            ownerTxt = cfg.npc_veh.stolen
        end
    end

    Wait(cfg.delay * 1000)

    lib.alertDialog({
        header = cfg.notify.title,
        content = (Lang['plate_lookup_result']):format(plate, vehLabel, ownerTxt),
        centered = true,
        cancel = false
    })

    if Config.T1GER_Insurance and ownerTxt ~= cfg.npc_veh.unreg and ownerTxt ~= cfg.npc_veh.stolen then
        TriggerEvent('t1ger_trafficpolicer:notify', (cfg.insurance):format(insuranceText))
    end
    PlayRadioSound()
end

function ImpoundClosestVehicle()
    local cfg = Config.ImpoundVehicle
    local coordA = GetEntityCoords(player, true)
    local coordB = GetOffsetFromEntityInWorldCoords(player, 0.0, cfg.dist, 0.0)
    local targetVeh = GetVehicleInDirection(coordA, coordB, 2.0)

    if not (DoesEntityExist(targetVeh) and IsEntityAVehicle(targetVeh)) then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['no_vehicle_nearby'], 'error')
        return
    end

    GetControlOfEntity(targetVeh)
    SetEntityAsMissionEntity(targetVeh, true, true)
    local d1 = GetModelDimensions(GetEntityModel(targetVeh))
    local impound_pos = GetOffsetFromEntityInWorldCoords(targetVeh, d1.x - 0.2, 0.0, 0.0)
    local impounded = false

    while not impounded do
        Wait(1)
        local dist = #(coords - impound_pos)
        if dist < cfg.drawText.dist then
            DrawText3Ds(impound_pos.x, impound_pos.y, impound_pos.z, cfg.drawText.str)
            if IsControlJustPressed(0, cfg.drawText.keybind) and dist <= cfg.drawText.interactDist then
                TaskTurnPedToFaceEntity(player, targetVeh, 1.0)
                Wait(400)
                SetCurrentPedWeapon(player, `WEAPON_UNARMED`, true)
                Wait(300)
                if cfg.freeze then FreezeEntityPosition(player, true) end
                TaskStartScenarioInPlace(player, cfg.scenario, 0, true)
                if Config.ProgressBars then
                    exports['progressBars']:startUI(cfg.progressBar.timer, cfg.progressBar.text)
                end
                Wait(cfg.progressBar.timer)
                ClearPedTasks(player)
                FreezeEntityPosition(player, false)
                impounded = true
            end
        end
    end

    local plate = plateText(targetVeh)
    if Config.T1GER_Garage then
        exports['t1ger_garage']:SetVehicleImpounded(targetVeh, false)
    else
        print('Insert garage impound update logic here if required.')
    end

    DeleteVehicle(targetVeh)
    TriggerEvent('t1ger_trafficpolicer:notify', (Lang['vehicle_impounded']):format(plate))
end

function UnlockClosestVehicle()
    local cfg = Config.UnlockVehicle
    local coordA = GetEntityCoords(player, true)
    local coordB = GetOffsetFromEntityInWorldCoords(player, 0.0, cfg.dist, 0.0)
    local targetVeh = GetVehicleInDirection(coordA, coordB, 2.0)

    if not (DoesEntityExist(targetVeh) and IsEntityAVehicle(targetVeh)) then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['no_vehicle_nearby'], 'error')
        return
    end

    GetControlOfEntity(targetVeh)
    SetEntityAsMissionEntity(targetVeh, true, true)
    local d1 = GetModelDimensions(GetEntityModel(targetVeh))
    local unlockPos = GetOffsetFromEntityInWorldCoords(targetVeh, d1.x - 0.2, 0.0, 0.0)
    local unlocked = false

    while not unlocked do
        Wait(1)
        local dist = #(coords - unlockPos)
        if dist < cfg.drawText.dist then
            DrawText3Ds(unlockPos.x, unlockPos.y, unlockPos.z, cfg.drawText.str)
            if IsControlJustPressed(0, cfg.drawText.keybind) and dist <= cfg.drawText.interactDist then
                LoadAnim(cfg.anim.dict)
                TaskTurnPedToFaceEntity(player, targetVeh, 1.0)
                Wait(400)
                SetCurrentPedWeapon(player, `WEAPON_UNARMED`, true)
                Wait(300)
                if cfg.freeze then FreezeEntityPosition(player, true) end
                TaskPlayAnim(player, cfg.anim.dict, cfg.anim.lib, 3.0, 3.0, -1, 31, 1.0, false, false, false)
                if Config.ProgressBars then
                    exports['progressBars']:startUI(cfg.progressBar.timer, cfg.progressBar.text)
                end
                Wait(cfg.progressBar.timer)
                ClearPedTasks(player)
                FreezeEntityPosition(player, false)
                unlocked = true
            end
        end
    end

    PlayVehicleDoorOpenSound(targetVeh, 0)
    SetVehicleDoorsLockedForAllPlayers(targetVeh, false)
    SetVehicleDoorsLocked(targetVeh, 1)
    if Config.T1GER_Keys then
        exports['t1ger_keys']:SetVehicleLocked(targetVeh, 0)
    end
    TriggerEvent('t1ger_trafficpolicer:notify', Lang['vehicle_unlocked'])
end

function SeizeClosestVehicle()
    local cfg = Config.SeizeVehicle
    local coordA = GetEntityCoords(player, true)
    local coordB = GetOffsetFromEntityInWorldCoords(player, 0.0, cfg.dist, 0.0)
    local targetVeh = GetVehicleInDirection(coordA, coordB, 2.0)

    if not (DoesEntityExist(targetVeh) and IsEntityAVehicle(targetVeh)) then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['no_vehicle_nearby'], 'error')
        return
    end

    GetControlOfEntity(targetVeh)
    SetEntityAsMissionEntity(targetVeh, true, true)
    local d1 = GetModelDimensions(GetEntityModel(targetVeh))
    local seizePos = GetOffsetFromEntityInWorldCoords(targetVeh, d1.x - 0.2, 0.0, 0.0)
    local seized = false

    while not seized do
        Wait(1)
        local dist = #(coords - seizePos)
        if dist < cfg.drawText.dist then
            DrawText3Ds(seizePos.x, seizePos.y, seizePos.z, cfg.drawText.str)
            if IsControlJustPressed(0, cfg.drawText.keybind) and dist <= cfg.drawText.interactDist then
                TaskTurnPedToFaceEntity(player, targetVeh, 1.0)
                Wait(400)
                SetCurrentPedWeapon(player, `WEAPON_UNARMED`, true)
                Wait(300)
                if cfg.freeze then FreezeEntityPosition(player, true) end
                TaskStartScenarioInPlace(player, cfg.scenario, 0, true)
                if Config.ProgressBars then
                    exports['progressBars']:startUI(cfg.progressBar.timer, cfg.progressBar.text)
                end
                Wait(cfg.progressBar.timer)
                ClearPedTasks(player)
                FreezeEntityPosition(player, false)
                seized = true
            end
        end
    end

    local plate = plateText(targetVeh)
    if Config.T1GER_Garage then
        exports['t1ger_garage']:SetVehicleImpounded(targetVeh, true)
    else
        print('Insert garage seize update logic here if required.')
    end

    DeleteVehicle(targetVeh)
    TriggerEvent('t1ger_trafficpolicer:notify', (Lang['vehicle_seized']):format(plate))
end

function BreathalyzerTest()
    local target = GetClosestPlayer()
    if not target then return end

    TriggerEvent('t1ger_trafficpolicer:notify', Lang['request_breathalyzer'])
    TriggerServerEvent('t1ger_trafficpolicer:requestBreathalyzerTest', GetPlayerServerId(target))
end

function DrugSwabTest()
    local target = GetClosestPlayer()
    if not target then return end

    TriggerEvent('t1ger_trafficpolicer:notify', Lang['request_drugswab'])
    TriggerServerEvent('t1ger_trafficpolicer:requestDrugSwabTest', GetPlayerServerId(target))
end

function PlayRadioSound()
    LoadAnim('random@arrests')
    local animLib = 'generic_radio_enter'
    if IsPlayerFreeAiming(PlayerId()) then
        animLib = 'radio_chatter'
    end
    TaskPlayAnim(player, 'random@arrests', animLib, 5.0, 2.0, -1, 50, 2.0, false, false, false)
    PlaySoundFrontend(-1, 'Start_Squelch', 'CB_RADIO_SFX', true)
    PlaySoundFrontend(-1, 'OOB_Start', 'GTAO_FM_Events_Soundset', true)
    Wait(1000)
    PlaySoundFrontend(-1, 'End_Squelch', 'CB_RADIO_SFX', true)
    Wait(500)
    ClearPedTasks(player)
end

