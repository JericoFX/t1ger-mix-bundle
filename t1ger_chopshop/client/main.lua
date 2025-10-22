-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 
local QBCore = exports[Config.CoreResource]:GetCoreObject()

local curVehicle
local driver

local TEXT_UI_ID = 't1ger_chopshop_prompt'
local activePrompt

local function setPromptText(text)
    if text and text ~= activePrompt then
        lib.showTextUI(text, { id = TEXT_UI_ID })
        activePrompt = text
    elseif not text and activePrompt then
        lib.hideTextUI()
        activePrompt = nil
    end
end

lib.onCache('vehicle', function(vehicle)
    curVehicle = vehicle
    if vehicle and vehicle ~= 0 then
        driver = GetPedInVehicleSeat(vehicle, -1)
    else
        driver = nil
    end
end)


local scrap_list 	= {}
local job_NPC 		= nil
local shop_blip 	= nil
local gotCarList	= false
local scrap_NPC		= nil
local jobPoint
local scrapPoint
local jobInteractionBusy = false
local activeContextFinish

local function finishInteraction()
    if activeContextFinish then
        activeContextFinish()
        activeContextFinish = nil
    end
end

local function handleContextClose(id)
    if id == 'chopshop_main_menu' or id == 'chopshop_select_risk_grade' then
        finishInteraction()
        jobInteractionBusy = false
    end
end

RegisterNetEvent('ox_lib:contextClosed', handleContextClose)
RegisterNetEvent('ox:context:close', handleContextClose)

-- Event to initialize chop shop:
RegisterNetEvent('t1ger_chopshop:intializeChopShop')
AddEventHandler('t1ger_chopshop:intializeChopShop', function(scrapList)
    scrap_list = scrapList

    if job_NPC then
        DeleteEntity(job_NPC)
        Wait(250)
    end

    local cfg = Config.ChopShop.JobNPC
    LoadModel(cfg.model)
    job_NPC = CreatePed(7, GetHashKey(cfg.model), cfg.pos[1], cfg.pos[2], cfg.pos[3] - 0.97, cfg.pos[4], false, true)
    FreezeEntityPosition(job_NPC, true)
    SetBlockingOfNonTemporaryEvents(job_NPC, true)
    TaskStartScenarioInPlace(job_NPC, cfg.scenario, 0, false)
    SetEntityInvincible(job_NPC, true)
    SetEntityAsMissionEntity(job_NPC)

    if jobPoint then
        jobPoint:remove()
        jobPoint = nil
    end

    jobPoint = lib.points.new({
        coords = vec3(cfg.pos[1], cfg.pos[2], cfg.pos[3]),
        distance = 20.0,
        onExit = function()
            setPromptText(nil)
            jobInteractionBusy = false
        end,
        nearby = function(self)
            if not DoesEntityExist(job_NPC) then
                return
            end

            if self.currentDistance <= 2.0 then
                if jobInteractionBusy then
                    return
                end

                setPromptText(Lang['press_to_talk'])

                if self.currentDistance <= 1.5 and IsControlJustPressed(0, Config.ChopShop.JobNPC.keybind) then
                    jobInteractionBusy = true
                    setPromptText(nil)
                    ChopShopMainMenu(function()
                        jobInteractionBusy = false
                    end)
                end
            elseif not jobInteractionBusy then
                setPromptText(nil)
            end
        end
    })

    local mk = Config.ChopShop.Blip
    if DoesBlipExist(shop_blip) then
        RemoveBlip(shop_blip)
    end

    if mk.enable then
        shop_blip = AddBlipForCoord(cfg.pos[1], cfg.pos[2], cfg.pos[3])
        SetBlipSprite(shop_blip, mk.sprite)
        SetBlipDisplay(shop_blip, mk.display)
        SetBlipScale(shop_blip, mk.scale)
        SetBlipColour(shop_blip, mk.color)
        SetBlipAsShortRange(shop_blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(mk.label)
        EndTextCommandSetBlipName(shop_blip)
    end

    gotCarList = false
end)


-- Interaction handled via ox_lib points


-- Function to talk with NPC:
function ChopShopMainMenu(onFinish)
    if not TalkWithNPC() then
        if onFinish then
            onFinish()
        end
        return
    end

    activeContextFinish = onFinish

    lib.registerContext({
        id = 'chopshop_main_menu',
        title = 'Chop Shop',
        options = {
            {
                title = Lang['menu_scrap_list'],
                onSelect = function()
                    if not Config.ChopShop.Police.allowCops and isCop then
                        ShowNotifyESX(Lang['police_not_allowed'], 'error')
                        finishInteraction()
                        return
                    end

                    QBCore.Functions.TriggerCallback('t1ger_chopshop:getCopsCount', function(cops)
                        if cops >= Config.ChopShop.Police.minCops then
                            QBCore.Functions.TriggerCallback('t1ger_chopshop:hasCooldown', function(cooldown)
                                if not cooldown then
                                    RetrieveCarList()
                                end
                                finishInteraction()
                            end, 'scrap')
                        else
                            ShowNotifyESX(Lang['not_enough_cops'], 'error')
                            finishInteraction()
                        end
                    end)
                end
            },
            {
                title = Lang['menu_thief_jobs'],
                onSelect = function()
                    if not Config.ChopShop.Police.allowCops and isCop then
                        ShowNotifyESX(Lang['police_not_allowed'], 'error')
                        finishInteraction()
                        return
                    end

                    QBCore.Functions.TriggerCallback('t1ger_chopshop:hasCooldown', function(cooldown)
                        if not cooldown then
                            CarThiefMainMenu(onFinish)
                        else
                            finishInteraction()
                        end
                    end, 'thief')
                end
            }
        }
    })

    lib.showContext('chopshop_main_menu')
end

-- Play Interaction Animation:
function TalkWithNPC()
    local cfg = Config.ChopShop.JobNPC
    LoadAnim(cfg.anim.dict)
    FreezeEntityPosition(player, true)
    TaskPlayAnim(player, cfg.anim.dict, cfg.anim.lib, 1.0, 0.5, -1, 31, 1.0, 0, 0)

    local success = true
    if Config.ProgressBars then
        success = lib.progressBar({
            duration = cfg.anim.time,
            label = Lang['progbar_talking'],
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true }
        })
    else
        Wait(cfg.anim.time)
    end

    ClearPedTasks(player)
    FreezeEntityPosition(player, false)

    return success ~= false
end

-- Function to Retrieve Car List:
function RetrieveCarList()
	local carNames = {}
	for k,v in pairs(scrap_list) do carNames[k] = v.label end
	local number = Config.ChopShop.JobNPC.name
	if not gotCarList then
		if Config.ChopShop.Settings.usePhoneMSG then
			JobNotifyMSG((Lang['get_these_cars_1']:format(table.concat(carNames, ", "))), number)
		else
			TriggerEvent('chat:addMessage', { args = {Lang['get_these_cars_2']:format(table.concat(carNames, ", "))}})
		end
		gotCarList = true	
	else
		if Config.ChopShop.Settings.usePhoneMSG then
			JobNotifyMSG((Lang['still_same_list_1']:format(table.concat(carNames, ", "))), number)
		else
			TriggerEvent('chat:addMessage', { args = {Lang['still_same_list_2']:format(table.concat(carNames, ", "))}})
		end
	end
end

-- Function for car thief main menu:
function CarThiefMainMenu(onFinish)
    activeContextFinish = onFinish

    local options = {}
    for _, v in pairs(Config.RiskGrades) do
        if v.enable then
            local list_label = ('%s [ $%s ]'):format(v.label, v.job_fees)
            options[#options + 1] = {
                title = list_label,
                onSelect = function()
                    TriggerServerEvent('t1ger_chopshop:selectRiskGrade', v.grade)
                    finishInteraction()
                end
            }
        end
    end

    lib.registerContext({
        id = 'chopshop_select_risk_grade',
        title = Lang['menu_thief_jobs'],
        options = options
    })

    lib.showContext('chopshop_select_risk_grade')
end

-- Event to browse through available locations:
RegisterNetEvent('t1ger_chopshop:BrowseAvailableJobs')
AddEventHandler('t1ger_chopshop:BrowseAvailableJobs',function(spot, grade, car)
	local id = math.random(1,#Config.ThiefJobs)
	local currentID = spot
	while Config.ThiefJobs[id].inUse and currentID < 100 do
		currentID = currentID + 1
		id = math.random(1,#Config.ThiefJobs)
	end
	if currentID == 100 then
		ShowNotifyESX(Lang['no_jobs_available'])
	else
		CarThiefJob(id, grade, car)
	end	
end)

local job_veh = nil
local goons = {}
local veh_lockpicked = false
local thiefjob_done = false
local scrappingCar = false
local inspectingCar = false
local carInspected = false
local carScrapped = false
local end_thiefJob = false
local veh_health = 0

-- Event for the job:
function CarThiefJob(id, grade, car)
	local job = Config.ThiefJobs[id]
	-- send message:
	local number = Config.ChopShop.JobNPC.name
	if Config.ChopShop.Settings.usePhoneMSG then
		JobNotifyMSG((Lang['steal_the_car']:format(car.name)), number)
	else
		ShowNotifyESX((Lang['steal_the_car']):format(car.name))
	end
	-- update config state:
	job.inUse = true
	TriggerServerEvent('t1ger_chopshop:syncDataSV', Config.ThiefJobs)
	-- create job blip:
	local thief_blip = CreateThiefJobBlip(job)
	-- thread:
	end_thiefJob = false
	while true do
		Citizen.Wait(1)
		local sleep = true 
		local distance = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, job.pos[1], job.pos[2], job.pos[3], false)
		if distance < 150.0 then
			sleep = false 
			-- Spawn Job Vehicle:
			if distance < 100.0 and not job.veh_spawned then
				ClearAreaOfVehicles(job.pos[1], job.pos[2], job.pos[3], 10.0, false, false, false, false, false)
				job_veh = CreateJobVehicle(car.hash, job.pos)
				job.veh_spawned = true
				TriggerServerEvent('t1ger_chopshop:syncDataSV', Config.ThiefJobs)
			end
			-- Spawn Goons:
			if grade == 2 or grade == 3 then
				if distance < 100.0 and not job.goons_spawned then
					ClearAreaOfPeds(job.pos[1], job.pos[2], job.pos[3], 10.0, 1)
					SetPedRelationshipGroupHash(player, GetHashKey("PLAYER"))
					AddRelationshipGroup('JobNPCs')
					for i = 1, #job.goons do
						goons[i] = CreateJobPed(job.goons[i], grade)
					end
					job.goons_spawned = true
					TriggerServerEvent('t1ger_chopshop:syncDataSV', Config.ThiefJobs)
				end
			end
			-- Activate NPC's:
			if distance < 60.0 and job.goons_spawned and not job.player then
				SetPedRelationshipGroupHash(player, GetHashKey("PLAYER"))
				AddRelationshipGroup('JobNPCs')
				for i = 1, #goons do 
					ClearPedTasksImmediately(goons[i])
					TaskCombatPed(goons[i], player, 0, 16)
					if Config.ChopShop.Settings.thiefjob.headshot then SetPedSuffersCriticalHits(goons[i], true) else SetPedSuffersCriticalHits(goons[i], false) end
					SetPedFleeAttributes(goons[i], 0, false)
					SetPedCombatAttributes(goons[i], 5, true)
					SetPedCombatAttributes(goons[i], 16, true)
					SetPedCombatAttributes(goons[i], 46, true)
					SetPedCombatAttributes(goons[i], 26, true)
					SetPedSeeingRange(goons[i], 75.0)
					SetPedHearingRange(goons[i], 50.0)
					SetPedEnableWeaponBlocking(goons[i], true)
				end
				SetRelationshipBetweenGroups(0, GetHashKey("JobNPCs"), GetHashKey("JobNPCs"))
				SetRelationshipBetweenGroups(5, GetHashKey("JobNPCs"), GetHashKey("PLAYER"))
				SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey("JobNPCs"))
				job.player = true
				TriggerServerEvent('t1ger_chopshop:syncDataSV', Config.ThiefJobs)
			end
			-- Lockpick Vehicle:
			local veh_pos = GetEntityCoords(job_veh) 
			local veh_dist = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, veh_pos.x, veh_pos.y, veh_pos.z, false)
			if veh_dist < 2.5 and not veh_lockpicked then
				DrawText3Ds(veh_pos.x, veh_pos.y, veh_pos.z, Lang['veh_lockpick'])
				if IsControlJustPressed(0, 47) then 
					LockpickJobVehicle(job)
					DrawJobVehHealth(job_veh)
					if DoesBlipExist(thief_blip) then RemoveBlip(thief_blip) end
				end
			end
			if veh_lockpicked then
				sleep = true
			end
		end
		-- End Job if these are true:
		if job.veh_spawned then
			if not DoesEntityExist(job_veh) then
				if not scrappingCar then
					end_thiefJob = true
					if Config.ChopShop.Settings.usePhoneMSG then JobNotifyMSG((Lang['car_is_taken']), number) else ShowNotifyESX(Lang['car_is_taken']) end
				end
			end
		end
		if veh_lockpicked and DoesEntityExist(job_veh) then
			local veh_pos = GetEntityCoords(job_veh)
			if GetDistanceBetweenCoords(coords, veh_pos.x, veh_pos.y, veh_pos.z, false) > 50.0 then 
				end_thiefJob = true
				if Config.ChopShop.Settings.usePhoneMSG then JobNotifyMSG(Lang['too_far_from_veh'], number) else ShowNotifyESX(Lang['too_far_from_veh']) end	
			end
		end
		-- end job:
		if end_thiefJob then 
			if thiefjob_done then 
				TriggerServerEvent('t1ger_chopshop:JobCompleteSV', car.payout, veh_health)
				if Config.ChopShop.Settings.usePhoneMSG then JobNotifyMSG(Lang['job_complete'], number) else ShowNotifyESX(Lang['job_complete']) end
			end
			thiefjob_done = false
			-- reset config data:
			Config.ThiefJobs[id].inUse = false
			Config.ThiefJobs[id].goons_spawned = false
			Config.ThiefJobs[id].veh_spawned = false
			Config.ThiefJobs[id].player = false
			TriggerServerEvent('t1ger_chopshop:syncDataSV', Config.ThiefJobs)
			Citizen.Wait(500)
			-- job vehicle:
			DeleteVehicle(job_veh)
			job_veh = nil
			-- blip:
			if DoesBlipExist(thief_blip) then RemoveBlip(thief_blip) end 
			thief_blip = nil
			-- goons:
			local i = 0
			for k,v in pairs(Config.ThiefJobs[id].goons) do
				if DoesEntityExist(goons[i]) then
					DeleteEntity(goons[i])
				end
				i = i +1
			end
			goons = {}
			veh_lockpicked = false
			end_thiefJob = false
			veh_health = 0
			break
		end
		if sleep then
			Citizen.Wait(1000)
		end
	end
end

-- Function to lockpick job vehicle:
function LockpickJobVehicle(job)
	local anim_dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
	local anim_lib = "machinic_loop_mechandplayer"
	LoadAnim(anim_dict)
	if Config.ChopShop.Police.alert.enable then AlertPoliceFunction() end
	SetCurrentPedWeapon(player, GetHashKey("WEAPON_UNARMED"),true)
	Citizen.Wait(250)
	FreezeEntityPosition(player, true)
	TaskPlayAnim(player, anim_dict, anim_lib, 3.0, 1.0, -1, 31, 0, 0, 0)
	-- Car Alarm:
	if Config.ChopShop.Settings.thiefjob.alarm then
                SetVehicleAlarm(job_veh, true)
                SetVehicleAlarmTimeLeft(job_veh, (25 * 1000))
                StartVehicleAlarm(job_veh)
        end
        if Config.ProgressBars then
                local progress = lib.progressCircle({
                    duration = 5000,
                    label = Lang['progbar_lockpick'],
                    useWhileDead = false,
                    canCancel = true,
                    position = 'bottom',
                    disable = { move = true, car = true, combat = true }
                })
                if not progress then
                        ClearPedTasks(player)
                        FreezeEntityPosition(player, false)
                        return
                end
        else
                Citizen.Wait(5000)
        end
        local skillPassed = lib.skillCheck({'easy', 'medium', 'medium'})
        if not skillPassed then
                ClearPedTasks(player)
                FreezeEntityPosition(player, false)
                ShowNotifyESX(Lang['lockpick_failed'], 'error')
                return
        end
        ClearPedTasks(player)
        FreezeEntityPosition(player, false)
	veh_lockpicked = true
	SetVehicleDoorsLockedForAllPlayers(job_veh, false)
	local number = Config.ChopShop.JobNPC.name
	if Config.ChopShop.Settings.usePhoneMSG then JobNotifyMSG(Lang['deliver_veh_msg'], number) else ShowNotifyESX(Lang['deliver_veh_msg']) end
end

-- Function to draw job vehicle health:
function DrawJobVehHealth(job_veh)
    Citizen.CreateThread(function()
        while veh_lockpicked and not scrappingCar do
            Citizen.Wait(1)
            veh_health = (GetEntityHealth(job_veh)/10)
            DrawVehHealthUtils(veh_health)
        end
    end)
end

-- Function for job blip in progress:
function CreateThiefJobBlip(job)
	local mk = job.blip
	local thief_blip = AddBlipForCoord(job.pos[1],job.pos[2],job.pos[3])
	SetBlipSprite(thief_blip, mk.sprite)
	SetBlipColour(thief_blip, mk.color)
	AddTextEntry('MYBLIP', mk.label)
	BeginTextCommandSetBlipName('MYBLIP')
	AddTextComponentSubstringPlayerName(name)
	EndTextCommandSetBlipName(thief_blip)
	SetBlipScale(thief_blip, mk.scale)
	SetBlipAsShortRange(thief_blip, true)
	if mk.route then
		SetBlipRoute(thief_blip, true)
		SetBlipRouteColour(thief_blip, mk.color)
	end
	return thief_blip
end

-- Function to create job vehicle:
function CreateJobVehicle(model, pos)
	LoadModel(model)
    local vehicle = CreateVehicle(model, pos[1], pos[2], pos[3], pos[4], true, false)
    SetVehicleNeedsToBeHotwired(vehicle, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleDoorsLockedForAllPlayers(vehicle, true)
    SetVehicleIsStolen(vehicle, false)
    SetVehicleIsWanted(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleFuelLevel(vehicle, 80.0)
    DecorSetFloat(vehicle, "_FUEL_LEVEL", GetVehicleFuelLevel(vehicle))
    return vehicle
end

-- Function to create job ped(s):
function CreateJobPed(goon, job_grade)
    LoadModel(goon.ped)
    local NPC = CreatePed(4, GetHashKey(goon.ped), goon.pos[1], goon.pos[2], goon.pos[3], goon.pos[4], false, true)
    NetworkRegisterEntityAsNetworked(NPC)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(NPC), true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(NPC), true)
    SetPedCanSwitchWeapon(NPC, true)
    SetPedArmour(NPC, goon.armour)
    SetPedAccuracy(NPC, goon.accuracy)
    SetEntityInvincible(NPC, false)
    SetEntityVisible(NPC, true)
    SetEntityAsMissionEntity(NPC)
    LoadAnim(goon.anim.dict)
    TaskPlayAnim(NPC, goon.anim.dict, goon.anim.lib, 8.0, -8, -1, 49, 0, 0, 0, 0)
    GiveWeaponToPed(NPC, GetHashKey(goon.weapon[job_grade]), 255, false, false)
    SetPedDropsWeaponsWhenDead(NPC, false)
    SetPedCombatAttributes(NPC, false)
    SetPedFleeAttributes(NPC, 0, false)
    SetPedEnableWeaponBlocking(NPC, true)
    SetPedRelationshipGroupHash(NPC, GetHashKey("JobNPCs"))	
    TaskGuardCurrentPosition(NPC, 15.0, 15.0, 1)
    return NPC
end

-- Event to sync config data:
RegisterNetEvent('t1ger_chopshop:syncDataCL')
AddEventHandler('t1ger_chopshop:syncDataCL',function(data)
    Config.ThiefJobs = data
end)

local function ensureScrapPoint()
    if scrapPoint then
        scrapPoint:remove()
    end

    local scrapCFG = Config.ChopShop.ScrapNPC
    local mk = scrapCFG.marker

    scrapPoint = lib.points.new({
        coords = vec3(scrapCFG.pos.veh[1], scrapCFG.pos.veh[2], scrapCFG.pos.veh[3]),
        distance = mk.drawDist,
        onExit = function()
            setPromptText(nil)
            if scrap_NPC then
                DeleteEntity(scrap_NPC)
                scrap_NPC = nil
            end
        end,
        nearby = function(self)
            local displayText
            local vehicle = curVehicle
            local carHash = vehicle and vehicle ~= 0 and GetEntityModel(vehicle) or 0

            if not (isInsideScrapCar(carHash) or (isInsideThiefJobCar(carHash) and veh_lockpicked)) then
                if scrap_NPC then
                    DeleteEntity(scrap_NPC)
                    scrap_NPC = nil
                end
                setPromptText(nil)
                return
            end

            if self.currentDistance > 2.0 then
                DrawMarker(mk.type, scrapCFG.pos.veh[1], scrapCFG.pos.veh[2], scrapCFG.pos.veh[3], 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, mk.scale.x, mk.scale.y, mk.scale.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, true, 2, false, nil, nil, false)
            end

            if not scrap_NPC then
                LoadModel(scrapCFG.model)
                scrap_NPC = CreatePed(4, scrapCFG.model, scrapCFG.pos.start[1], scrapCFG.pos.start[2], scrapCFG.pos.start[3] - 0.975, scrapCFG.pos.start[4], false, true)
                FreezeEntityPosition(scrap_NPC, true)
                SetEntityInvincible(scrap_NPC, true)
                SetBlockingOfNonTemporaryEvents(scrap_NPC, true)
                TaskStartScenarioInPlace(scrap_NPC, scrapCFG.scenario.idle, 0, false)
            end

            if carInspected and not carScrapped and scrap_NPC then
                local npc_coords = GetEntityCoords(scrap_NPC)
                local playerCoords = coords or GetEntityCoords(player)
                local npc_dist = #(playerCoords - npc_coords)

                if npc_dist < 6.0 then
                    displayText = Lang['press_to_receive_cash']
                    if npc_dist <= 2.0 then
                        if IsControlJustPressed(0, scrapCFG.keybind) then
                            ScrapVehicle()
                            return
                        end
                    else
                        DrawText3Ds(npc_coords.x, npc_coords.y, npc_coords.z, Lang['press_to_receive_cash'])
                    end
                end
            elseif not scrappingCar then
                if self.currentDistance <= 2.0 then
                    displayText = Lang['press_to_scrap']
                    if IsControlJustPressed(0, scrapCFG.keybind) then
                        InspectScrapVehicle()
                    end
                end
            end

            setPromptText(displayText)
        end
    })
end

ensureScrapPoint()


-- Function to scrap vehicle & reward:
function ScrapVehicle()
	carScrapped = true
	local scrapCFG = Config.ChopShop.ScrapNPC
	local scrap_vehicle = GetClosestVehicle(scrapCFG.pos.veh[1], scrapCFG.pos.veh[2], scrapCFG.pos.veh[3], 5.0, 0, 70)
	-- Trigger Reward:
	if job_veh ~= nil or veh_lockpicked then
		thiefjob_done = true
	else 
		-- (Delete Owned Vehicle):
		local plate = GetVehicleNumberPlateText(scrap_vehicle):gsub("^%s*(.-)%s*$", "%1")
		if Config.ChopShop.Settings.ownedVehicles.delete then
			QBCore.Functions.TriggerCallback('t1ger_chopshop:isVehicleOwned', function(owned)
				if owned then
					TriggerServerEvent('t1ger_chopshop:deleteOwnedVehicle', plate)
				end
			end, plate)
		end
		-- reward:
		local data = GetScrapVehicleDetails(GetEntityModel(scrap_vehicle))
		TriggerServerEvent('t1ger_chopshop:getPayment', data, round(GetEntityHealth(scrap_vehicle)/10, 0), plate)
		if Config.ChopShop.Settings.usePhoneMSG then
			JobNotifyMSG(Lang['car_delivered_1'], scrapCFG.name)
		else
			TriggerEvent('chat:addMessage', { args = {Lang['car_delivered_2']}})
		end
	end
	-- Reset & Stop:
	DeleteEntity(scrap_vehicle)
	DeleteVehicle(scrap_vehicle)
	FreezeEntityPosition(scrap_NPC, false)
	SetBlockingOfNonTemporaryEvents(scrap_NPC, true)
	SetEntityInvincible(scrap_NPC, true)
	TaskGoToCoordAnyMeans(scrap_NPC, scrapCFG.pos.start[1], scrapCFG.pos.start[2], scrapCFG.pos.start[3], 1.0, 0, 0, 786603, 0xbf800000)
	SetEntityHeading(scrap_NPC, scrapCFG.pos.start[4])
	Citizen.Wait(scrapCFG.timer.back * 1000)
	DeleteEntity(scrap_NPC)
	inspectingCar = false
	scrappingCar = false
	carInspected = false
	curVehicle = nil
	scrap_NPC = nil
	carScrapped	= false
        setPromptText(nil)
end

-- Function to inspect vehicle:
function InspectScrapVehicle()
	local plate = GetVehicleNumberPlateText(curVehicle):gsub("^%s*(.-)%s*$", "%1")
	local checked = false
	local can_scrap, checked = CanScrapVehicle(plate)
	while not checked do Wait(100) end
	if can_scrap then
		local scrapCFG = Config.ChopShop.ScrapNPC
		-- Check if Driver:
		if driver then 
			SetEntityAsMissionEntity(curVehicle, true)
			SetVehicleForwardSpeed(curVehicle, 0)
			SetVehicleEngineOn(curVehicle, false, false, true)
			if IsPedInAnyVehicle(player, true) then
				TaskLeaveVehicle(player, curVehicle, 4160)
				SetVehicleDoorsLockedForAllPlayers(curVehicle, true)
			end
			Citizen.Wait(250)
			FreezeEntityPosition(curVehicle, true)
		else
			return ShowNotifyESX(Lang['must_be_driver'])
		end
		scrappingCar = true 
		-- Inspect Car:
		if scrap_NPC ~= nil and not inspectingCar then
			FreezeEntityPosition(scrap_NPC, false)
			SetBlockingOfNonTemporaryEvents(scrap_NPC, true)
			SetEntityInvincible(scrap_NPC, true)
			TaskGoToCoordAnyMeans(scrap_NPC, scrapCFG.pos.stop[1], scrapCFG.pos.stop[2], scrapCFG.pos.stop[3], 1.0, 0, 0, 786603, 0xbf800000)
			SetEntityHeading(scrap_NPC, scrapCFG.pos.stop[4])
			Citizen.Wait(scrapCFG.timer.toCar * 1000)
			inspectingCar = true
		end	
		--Car Inspected:
		if scrap_NPC ~= nil and inspectingCar and not carInspected then	
			FreezeEntityPosition(scrap_NPC, true)
			SetEntityHeading(scrap_NPC, scrapCFG.pos.stop[4])
			SetBlockingOfNonTemporaryEvents(scrap_NPC, true)
			TaskStartScenarioInPlace(scrap_NPC, scrapCFG.scenario.work, 0, false)
			Citizen.Wait(scrapCFG.timer.inspect * 1000)
			carInspected = true
		end
	end
end

-- Check if inside a car from the car-list:
function isInsideScrapCar(hashkey)
	if hashkey == 0 then return false end
    for k,v in pairs(scrap_list) do
        if hashkey == v.hash then
            return true
        end
        if k == #scrap_list then
            return false
        end
    end
end

-- Check if inside a car from the current thief job:
function isInsideThiefJobCar(hashkey)
	if hashkey == 0 then return false end
	if hashkey == GetEntityModel(job_veh) then 
		return true 
	end
end

-- function to check if vehicle can be scrapped:
function CanScrapVehicle(plate)
	local canScrapVeh = false
	if job_veh ~= nil then return true, true end
	if Config.ChopShop.Settings.ownedVehicles.scrap then
		canScrapVeh = true 
	else
		QBCore.Functions.TriggerCallback('t1ger_chopshop:isVehicleOwned', function(owned)
			if owned then canScrapVeh = false else canScrapVeh = true end
		end, plate)
	end
	return canScrapVeh, true
end

-- Get the  current scrap vehicle:
function GetScrapVehicleDetails(hashkey)
    local data = {}
    for k,v in pairs(scrap_list) do
        if hashkey == v.hash then
            data = {label = v.label, hash = v.hash, price = v.price}
            return data
        end
    end
end

AddEventHandler('baseevents:onPlayerDied', function()
    end_thiefJob = true
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    end_thiefJob = true
end)

RegisterCommand('carthief_cancel', function(source, args)
    end_thiefJob = true
    ShowNotifyESX(Lang['cancel_job'])
end, false)
