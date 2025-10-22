-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local QBCore = exports[Config.CoreResource]:GetCoreObject()
local BAC_table = {}
local BDC_table = {}
local anpr_table = {}
local ActiveCitations = {}

math.randomseed(os.time())

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function playerGender(Player)
    local gender = Player.PlayerData.charinfo.gender
    if type(gender) == 'string' then
        return gender == 'M' or gender == 'm' or gender == 'male'
    end
    return gender == 0
end

local function InitializeBAC(Player)
    BAC_table[Player.PlayerData.citizenid] = { BAC = 0, hour = 0, gram = 0 }
    TriggerClientEvent('t1ger_trafficpolicer:setBAC', Player.PlayerData.source, 0, 0)
end

local function InitializeBDC(Player)
    local dataSV = {}
    for i = 1, #Config.DrugSwab.labels do
        dataSV[Config.DrugSwab.labels[i]] = { drug = Config.DrugSwab.labels[i], duration = 0, result = false }
    end
    BDC_table[Player.PlayerData.citizenid] = { data = dataSV, onDrugs = false }
    TriggerClientEvent('t1ger_trafficpolicer:setBDC', Player.PlayerData.source, dataSV, false)
end

local function syncPlayer(source)
    local Player = getPlayer(source)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    TriggerClientEvent('t1ger_trafficpolicer:updateGender', source, playerGender(Player))

    if BAC_table[cid] then
        TriggerClientEvent('t1ger_trafficpolicer:setBAC', source, BAC_table[cid].BAC, BAC_table[cid].gram)
    else
        InitializeBAC(Player)
    end

    if BDC_table[cid] then
        TriggerClientEvent('t1ger_trafficpolicer:setBDC', source, BDC_table[cid].data, BDC_table[cid].onDrugs)
    else
        InitializeBDC(Player)
    end

    TriggerClientEvent('t1ger_trafficpolicer:loadANPR', source, anpr_table)
end

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    syncPlayer(Player.PlayerData.source)
end)

RegisterNetEvent('t1ger_trafficpolicer:playerReady', function()
    syncPlayer(source)
end)

lib.callback.register('t1ger_trafficpolicer:lookupPlayer', function(source, target)
    local targetPlayer = getPlayer(target)
    if not targetPlayer then return nil end

    local charinfo = targetPlayer.PlayerData.charinfo or {}
    local data = {
        firstname = charinfo.firstname or 'Unknown',
        lastname = charinfo.lastname or 'Unknown',
        dob = charinfo.birthdate or 'Unknown',
        sex = charinfo.gender or 0,
        license = false
    }

    if Config.UseQBLicenses then
        local licences = targetPlayer.PlayerData.metadata and targetPlayer.PlayerData.metadata.licences
        if licences then
            data.license = licences.driver == true or licences['driver'] == true
        end
    end

    return data
end)

local function decodeCharinfo(charinfo)
    if type(charinfo) == 'string' then
        local ok, result = pcall(json.decode, charinfo)
        if ok and result then
            return result
        end
    elseif type(charinfo) == 'table' then
        return charinfo
    end
    return {}
end

lib.callback.register('t1ger_trafficpolicer:lookupPlate', function(source, plate)
    if not plate or plate == '' then return nil end
    local results = MySQL.query.await('SELECT pv.citizenid, pv.plate, pv.vehicle, pv.metadata, pv.insurance, p.charinfo FROM player_vehicles pv INNER JOIN players p ON pv.citizenid = p.citizenid WHERE pv.plate = ? LIMIT 1', { plate })
    local row = results and results[1]
    if not row then return nil end

    local charinfo = decodeCharinfo(row.charinfo)
    local data = {
        firstname = charinfo.firstname or 'Unknown',
        lastname = charinfo.lastname or 'Unknown',
        dob = charinfo.birthdate or 'Unknown',
        insurance = nil
    }

    if Config.T1GER_Insurance then
        local insurance = row.insurance
        if insurance == nil and row.metadata then
            local ok, metadata = pcall(json.decode, row.metadata)
            if ok and metadata and metadata.insurance ~= nil then
                insurance = metadata.insurance
            end
        end
        if insurance ~= nil then
            data.insurance = insurance == true or insurance == 1 or insurance == '1'
        end
    end

    return data
end)

RegisterNetEvent('t1ger_trafficpolicer:startDebug')
AddEventHandler('t1ger_trafficpolicer:startDebug', function()
    local Player = getPlayer(source)
    if not Player then return end
    InitializeBDC(Player)
    InitializeBAC(Player)
end)

RegisterNetEvent('t1ger_trafficpolicer:updateBAC')
AddEventHandler('t1ger_trafficpolicer:updateBAC', function(male, gram)
    local Player = getPlayer(source)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    local weight = 0
    if male then
        weight = ((Config.Breathalyzer.weight.male * 1000) * 0.68)
    else
        weight = ((Config.Breathalyzer.weight.female * 1000) * 0.55)
    end

    local addGram = gram
    if BAC_table[cid] and BAC_table[cid].gram > addGram then
        addGram = BAC_table[cid].gram
    end

    local addHours = 1
    if BAC_table[cid] then
        addHours = BAC_table[cid].hour + 1
    end

    local addBAC = ((addGram / weight) * 100)
    if addHours > 0 then
        addBAC = addBAC - (Config.Breathalyzer.decreaser * addHours)
        if addBAC <= 0.00 then
            BAC_table[cid] = nil
            TriggerClientEvent('t1ger_trafficpolicer:setBAC', Player.PlayerData.source, 0, 0)
            return
        end
    end

    BAC_table[cid] = { BAC = addBAC, hour = addHours, gram = addGram }
    TriggerClientEvent('t1ger_trafficpolicer:setBAC', Player.PlayerData.source, addBAC, gram)
end)

RegisterNetEvent('t1ger_trafficpolicer:requestBreathalyzerTest')
AddEventHandler('t1ger_trafficpolicer:requestBreathalyzerTest', function(target)
    local officer = getPlayer(source)
    local offender = getPlayer(target)
    if officer and offender then
        TriggerClientEvent('t1ger_trafficpolicer:acceptBreathalyzerTest', offender.PlayerData.source, officer.PlayerData.source)
    end
end)

RegisterNetEvent('t1ger_trafficpolicer:sendBreathalyzerTest')
AddEventHandler('t1ger_trafficpolicer:sendBreathalyzerTest', function(target, provided, BAC)
    local officer = getPlayer(target)
    if not officer then return end
    if provided then
        TriggerClientEvent('t1ger_trafficpolicer:getBreathalyzerTestResults', officer.PlayerData.source, BAC)
    else
        TriggerClientEvent('t1ger_trafficpolicer:notify', officer.PlayerData.source, Lang['rejected_bac_test'], 'error')
    end
end)

RegisterNetEvent('t1ger_trafficpolicer:updateBDC')
AddEventHandler('t1ger_trafficpolicer:updateBDC', function(tableData)
    local Player = getPlayer(source)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    local state = false

    for i = 1, #Config.DrugSwab.labels do
        local label = Config.DrugSwab.labels[i]
        local entry = tableData[label]
        if entry then
            if entry.duration > 0 then
                entry.duration = entry.duration - Config.DrugSwab.decreaser
                if entry.duration < 0 then entry.duration = 0 end
                entry.result = entry.duration > 0
            else
                entry.duration = 0
                entry.result = false
            end
            if entry.result then state = true end
        end
    end

    BDC_table[cid] = { data = tableData, onDrugs = state }
    TriggerClientEvent('t1ger_trafficpolicer:setBDC', Player.PlayerData.source, tableData, state)
end)

RegisterNetEvent('t1ger_trafficpolicer:requestDrugSwabTest')
AddEventHandler('t1ger_trafficpolicer:requestDrugSwabTest', function(target)
    local officer = getPlayer(source)
    local offender = getPlayer(target)
    if officer and offender then
        TriggerClientEvent('t1ger_trafficpolicer:acceptDrugSwabTest', offender.PlayerData.source, officer.PlayerData.source)
    end
end)

RegisterNetEvent('t1ger_trafficpolicer:sendDrugSwabTest')
AddEventHandler('t1ger_trafficpolicer:sendDrugSwabTest', function(target, provided, onDrugs, BDC)
    local officer = getPlayer(target)
    if not officer then return end
    if provided then
        TriggerClientEvent('t1ger_trafficpolicer:getDrugSwabTestResults', officer.PlayerData.source, BDC)
    else
        TriggerClientEvent('t1ger_trafficpolicer:notify', officer.PlayerData.source, Lang['rejected_bdc_test'], 'error')
    end
end)

local function isOfficerAuthorized(Player)
    local cfg = Config.CitationPermissions
    if not cfg.job then return true end

    local job = Player.PlayerData.job.name
    if job ~= cfg.job then return false end

    local grade = Player.PlayerData.job.grade and (Player.PlayerData.job.grade.level or Player.PlayerData.job.grade) or 0
    if grade >= cfg.minGrade then
        return true
    end

    for _, citizenid in ipairs(cfg.allowList) do
        if citizenid == Player.PlayerData.citizenid then
            return true
        end
    end

    return false
end

local function randomSignature(length)
    local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local signature = {}
    for i = 1, length do
        local index = math.random(#charset)
        signature[i] = charset:sub(index, index)
    end
    return table.concat(signature)
end

lib.callback.register('t1ger_trafficpolicer:issueCitation', function(source, payload)
    local officer = getPlayer(source)
    if not officer then
        return { success = false, error = Lang['citation_officer_missing'] }
    end

    if not isOfficerAuthorized(officer) then
        return { success = false, error = Lang['citation_permission_denied'] }
    end

    if not payload or not payload.offences or #payload.offences == 0 or (payload.fine or 0) <= 0 then
        return { success = false, error = Lang['empty_citation_error'] }
    end

    local offender = getPlayer(payload.target)
    if not offender then
        return { success = false, error = Lang['no_players_nearby'] }
    end

    local signature = randomSignature(Config.Security.signatureLength)
    local expires = os.time() + Config.Security.signatureTTL

    ActiveCitations[signature] = {
        officer = source,
        officerCid = officer.PlayerData.citizenid,
        officerName = (officer.PlayerData.charinfo.firstname or '') .. ' ' .. (officer.PlayerData.charinfo.lastname or ''),
        offender = offender.PlayerData.source,
        offenderCid = offender.PlayerData.citizenid,
        fine = payload.fine,
        offences = payload.offences,
        note = payload.note or '',
        expires = expires,
        paid = false
    }

    TriggerClientEvent('t1ger_trafficpolicer:receiveCitation', offender.PlayerData.source, {
        signature = signature,
        fine = payload.fine,
        offences = payload.offences,
        note = payload.note or '',
        officer = {
            source = officer.PlayerData.source,
            citizenid = officer.PlayerData.citizenid,
            name = ActiveCitations[signature].officerName
        },
        expires = expires
    })

    return { success = true }
end)

local function persistCitation(data, signature)
    local offences = json.encode(data.offences or {})
    MySQL.insert.await('INSERT INTO t1ger_citations (officer_cid, offender_cid, fine, offences, note, paid, signature, issued_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        data.officerCid,
        data.offenderCid,
        data.fine,
        offences,
        data.note,
        data.paid and 1 or 0,
        signature,
        os.time()
    })
end

RegisterNetEvent('t1ger_trafficpolicer:resolveCitation')
AddEventHandler('t1ger_trafficpolicer:resolveCitation', function(signature, accept)
    local src = source
    local data = ActiveCitations[signature]
    if not data then
        TriggerClientEvent('t1ger_trafficpolicer:notify', src, Lang['citation_signature_invalid'], 'error')
        return
    end

    if data.offender ~= src then
        TriggerClientEvent('t1ger_trafficpolicer:notify', src, Lang['citation_signature_invalid'], 'error')
        return
    end

    if Config.Security.useDigitalSignature and os.time() > data.expires then
        TriggerClientEvent('t1ger_trafficpolicer:notify', data.offender, Lang['citation_signature_expired'], 'error')
        TriggerClientEvent('t1ger_trafficpolicer:notify', data.officer, Lang['citation_signature_expired'], 'error')
        ActiveCitations[signature] = nil
        return
    end

    local offender = getPlayer(data.offender)
    local officer = getPlayer(data.officer)
    if not offender or not officer then
        ActiveCitations[signature] = nil
        return
    end

    if accept then
        local bank = offender.PlayerData.money.bank or 0
        if bank >= data.fine then
            offender.Functions.RemoveMoney('bank', data.fine, 'traffic-citation')
            TriggerClientEvent('t1ger_trafficpolicer:notify', offender.PlayerData.source, Lang['citiation_signed1'])
            TriggerClientEvent('t1ger_trafficpolicer:notify', officer.PlayerData.source, Lang['citiation_signed2'])
            data.paid = true
        else
            TriggerClientEvent('t1ger_trafficpolicer:notify', offender.PlayerData.source, Lang['citiation_no_money1'], 'error')
            TriggerClientEvent('t1ger_trafficpolicer:notify', officer.PlayerData.source, Lang['citiation_no_money2'], 'error')
            data.paid = false
        end
    else
        TriggerClientEvent('t1ger_trafficpolicer:notify', offender.PlayerData.source, Lang['citiation_not_signed1'], 'error')
        TriggerClientEvent('t1ger_trafficpolicer:notify', officer.PlayerData.source, Lang['citiation_not_signed2'], 'error')
        data.paid = false
    end

    persistCitation(data, signature)
    ActiveCitations[signature] = nil
end)

Citizen.CreateThread(function()
    Wait(1000)
    local results = MySQL.query.await('SELECT * FROM t1ger_anpr', {})
    if results then
        for i = 1, #results do
            anpr_table[results[i].plate] = {
                citizenid = results[i].citizenid,
                plate = results[i].plate,
                stolen = results[i].stolen == 1,
                bolo = results[i].bolo == 1,
                owner = results[i].owner,
                insurance = results[i].insurance == 1
            }
        end
        TriggerClientEvent('t1ger_trafficpolicer:loadANPR', -1, anpr_table)
    end
end)

RegisterNetEvent('t1ger_trafficpolicer:updateANPR')
AddEventHandler('t1ger_trafficpolicer:updateANPR', function(plate, field, state)
    local updated = false
    if anpr_table[plate] then
        if field == Config.ANPR.args.stolen then
            anpr_table[plate].stolen = state
        elseif field == Config.ANPR.args.bolo then
            anpr_table[plate].bolo = state
        end
        updated = true
    else
        local vehicle = MySQL.query.await('SELECT pv.citizenid, pv.plate, p.charinfo, pv.insurance FROM player_vehicles pv INNER JOIN players p ON pv.citizenid = p.citizenid WHERE pv.plate = ? LIMIT 1', { plate })
        if vehicle and vehicle[1] then
            local charinfo = decodeCharinfo(vehicle[1].charinfo)
            local owner = json.encode({ firstname = charinfo.firstname or 'Unknown', lastname = charinfo.lastname or 'Unknown' })
            anpr_table[plate] = {
                citizenid = vehicle[1].citizenid,
                plate = plate,
                stolen = field == Config.ANPR.args.stolen and state or false,
                bolo = field == Config.ANPR.args.bolo and state or false,
                owner = owner,
                insurance = vehicle[1].insurance == 1
            }
            MySQL.insert.await('INSERT INTO t1ger_anpr (citizenid, plate, stolen, bolo, owner, insurance) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE stolen = VALUES(stolen), bolo = VALUES(bolo), owner = VALUES(owner), insurance = VALUES(insurance)', {
                anpr_table[plate].citizenid,
                anpr_table[plate].plate,
                anpr_table[plate].stolen and 1 or 0,
                anpr_table[plate].bolo and 1 or 0,
                owner,
                anpr_table[plate].insurance and 1 or 0
            })
            updated = true
        end
    end

    if updated then
        TriggerClientEvent('t1ger_trafficpolicer:loadANPR', -1, anpr_table)
    end
end)

local function UpdateDatabaseData()
    for plate, data in pairs(anpr_table) do
        MySQL.update.await('UPDATE t1ger_anpr SET stolen = ?, bolo = ?, owner = ?, insurance = ? WHERE plate = ?', {
            data.stolen and 1 or 0,
            data.bolo and 1 or 0,
            data.owner,
            data.insurance and 1 or 0,
            plate
        })
    end
end

local function StartDatabaseSync()
    local function SaveData()
        UpdateDatabaseData()
        SetTimeout(Config.ANPR.syncDelay * 60 * 1000, SaveData)
    end

    SetTimeout(Config.ANPR.syncDelay * 60 * 1000, SaveData)
end

StartDatabaseSync()

