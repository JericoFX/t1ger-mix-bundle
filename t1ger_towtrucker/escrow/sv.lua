function InitializeTowTrucker()
        Wait(1000)
        towServices = {}
        local results = MySQL.query.await('SELECT * FROM t1ger_towtrucker', {})
        if results and next(results) then
                for i = 1, #results do
                        local data = {
                                identifier = results[i].identifier,
                                id = results[i].id,
                                name = results[i].name,
                                impound = results[i].impound and json.decode(results[i].impound) or {}
                        }
                        towServices[results[i].id] = data
                        if Config.TowServices[results[i].id] then
                                Config.TowServices[results[i].id].owned = true
                                Config.TowServices[results[i].id].data = data
                        end
                        Wait(5)
                end
        end
        print('[t1ger_towtrucker] Tow Trucker Initialized')
end

function UpdateTowServices(num, val, state, name, identify)
    if state ~= nil then
        if state then
            towServices[num] = { identifier = identify, id = num, name = name or (towServices[num] and towServices[num].name) }
            if Config.TowServices[num] then
                Config.TowServices[num].owned = true
                Config.TowServices[num].data = towServices[num]
            end
        else
                towServices[num] = nil
                if Config.TowServices[num] then
                        Config.TowServices[num].owned = false
                        Config.TowServices[num].data = nil
                end
        end
    elseif name ~= nil then
        for _, v in pairs(towServices) do
            if v.id == num then
                v.name = name
                MySQL.update.await('UPDATE t1ger_towtrucker SET name = ? WHERE id = ?', { name, num })
                break
            end
        end
    end
    TriggerClientEvent('t1ger_towtrucker:syncTowServices', -1, towServices, Config.TowServices)
end

RegisterNetEvent('t1ger_towtrucker:debugSV')
AddEventHandler('t1ger_towtrucker:debugSV', function()
    SetupTowServices(source)
end)

function T1GER_Trim(value)
        return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end
