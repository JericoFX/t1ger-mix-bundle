
RegisterNetEvent('t1ger_heistpreps:sendConfigCL')
AddEventHandler('t1ger_heistpreps:sendConfigCL', function(type, num, cfg)
	Config.Jobs[type][num] = cfg
end)

RegisterNetEvent('t1ger_heistpreps:sendCacheCL')
AddEventHandler('t1ger_heistpreps:sendCacheCL', function(data, type, num)
        Config.Jobs[type][num].cache = data
end)

local randomSeeded = false

local function ensureRandomSeed()
        if randomSeeded then return end
        math.randomseed(GetCloudTimeAsInt() + GetGameTimer())
        math.random(); math.random(); math.random()
        randomSeeded = true
end

function GetRandomJobType()
        ensureRandomSeed()
        return Config.Types[math.random(1, #Config.Types)]
end

function GetRandomJobLocation(type)
        ensureRandomSeed()
        local available = {}
        for index = 1, #Config.Jobs[type] do
                if not Config.Jobs[type][index].inUse then
                        available[#available + 1] = index
                end
        end
        if #available == 0 then
                return nil
        end
        return available[math.random(1, #available)]
end

function IsPhoneBoxAllowed(coords)
	local obj = 0
	for k,v in pairs(Config.PhoneBoxes) do
		obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, GetHashKey(v), false, false, false)
		if obj > 0 then
			return obj, true
		end
	end
	return obj, false
end
