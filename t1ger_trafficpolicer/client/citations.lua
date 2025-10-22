-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local total_fine = 0
local added_citations = {}
local citation_note = ''

local function resetCitation()
    total_fine = 0
    added_citations = {}
    citation_note = ''
end

local function recalcTotal()
    local sum = 0
    for _, entry in ipairs(added_citations) do
        sum = sum + (entry.fine or 0)
    end
    total_fine = sum
end

local function formatFine(amount)
    return comma_value(tostring(amount))
end

local function isOffenceSelected(category, index)
    for _, entry in ipairs(added_citations) do
        if entry.category == category and entry.index == index then
            return true
        end
    end
    return false
end

function OpenCitationMain()
    recalcTotal()
    local options = {
        {
            title = Lang['select_offences'],
            description = (Lang['citations_total']):format(formatFine(total_fine)),
            icon = 'fa-solid fa-list-check',
            onSelect = SelectOffenceCategory
        },
        {
            title = Lang['view_selected_offences'],
            description = (#added_citations > 0) and Lang['offences_available'] or Lang['no_offences_selected'],
            icon = 'fa-solid fa-eye',
            onSelect = ViewSelectedOffences
        },
        {
            title = Lang['add_citation_note'],
            description = (citation_note ~= '' and citation_note) or Lang['note_empty'],
            icon = 'fa-solid fa-pen-to-square',
            onSelect = AddCitationNotes
        },
        {
            title = Lang['issue_citation'],
            description = Lang['issue_citation_hint'],
            icon = 'fa-solid fa-ticket',
            onSelect = IssueCitation
        },
        {
            title = Lang['clear_citation'],
            icon = 'fa-solid fa-rotate-right',
            onSelect = function()
                resetCitation()
                TriggerEvent('t1ger_trafficpolicer:notify', Lang['citation_reset'])
                OpenCitationMain()
            end
        }
    }

    lib.registerContext({
        id = 't1ger_citations_main',
        title = Lang['citations_main_title'],
        options = options
    })

    lib.showContext('t1ger_citations_main')
end

function SelectOffenceCategory()
    local options = {}
    for label, offences in pairs(Config.Citations) do
        options[#options + 1] = {
            title = label,
            icon = 'fa-solid fa-scale-balanced',
            onSelect = function()
                SelectOffenceFromCategory(label, offences)
            end
        }
    end

    table.sort(options, function(a, b) return a.title < b.title end)

    lib.registerContext({
        id = 't1ger_citations_categories',
        title = Lang['select_category'],
        menu = 't1ger_citations_main',
        options = options
    })

    lib.showContext('t1ger_citations_categories')
end

function SelectOffenceFromCategory(label, entries)
    local options = {}
    for index, entry in ipairs(entries) do
        if not isOffenceSelected(label, index) then
            options[#options + 1] = {
                title = string.format('%s [$%s]', entry.offence, formatFine(entry.amount)),
                description = label,
                icon = 'fa-solid fa-circle-plus',
                onSelect = function()
                    table.insert(added_citations, {
                        category = label,
                        offence = entry.offence,
                        fine = entry.amount,
                        index = index
                    })
                    recalcTotal()
                    TriggerEvent('t1ger_trafficpolicer:notify', Lang['citation_added'])
                    SelectOffenceFromCategory(label, entries)
                end
            }
        end
    end

    if #options == 0 then
        options[1] = {
            title = Lang['no_offences_left'],
            description = label,
            icon = 'fa-solid fa-ban',
            disabled = true
        }
    end

    lib.registerContext({
        id = 't1ger_citations_category_entries',
        title = label,
        menu = 't1ger_citations_categories',
        options = options
    })

    lib.showContext('t1ger_citations_category_entries')
end

function ViewSelectedOffences()
    if #added_citations == 0 then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['no_offences_selected'], 'error')
        return
    end

    local options = {}
    for index, entry in ipairs(added_citations) do
        options[#options + 1] = {
            title = string.format('%s [$%s]', entry.offence, formatFine(entry.fine)),
            description = entry.category,
            icon = 'fa-solid fa-trash-can',
            onSelect = function()
                table.remove(added_citations, index)
                recalcTotal()
                ViewSelectedOffences()
            end
        }
    end

    lib.registerContext({
        id = 't1ger_citations_selected',
        title = Lang['view_selected_offences'],
        menu = 't1ger_citations_main',
        options = options
    })

    lib.showContext('t1ger_citations_selected')
end

function AddCitationNotes()
    local input = lib.inputDialog(Lang['add_note_title'], {
        {
            type = 'textarea',
            label = Lang['add_note_label'],
            description = Lang['add_note_description'],
            required = false,
            max = 255,
            default = citation_note
        }
    })

    if input and input[1] then
        citation_note = input[1]
        if citation_note ~= '' then
            TriggerEvent('t1ger_trafficpolicer:notify', Lang['note_added'])
        else
            TriggerEvent('t1ger_trafficpolicer:notify', Lang['note_cleared'])
        end
    end
    OpenCitationMain()
end

function IssueCitation()
    recalcTotal()
    if total_fine <= 0 then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['empty_citation_error'], 'error')
        return
    end

    local target = GetClosestPlayer()
    if not target then return end

    local payload = {
        target = GetPlayerServerId(target),
        fine = total_fine,
        offences = added_citations,
        note = citation_note
    }

    local response = lib.callback.await('t1ger_trafficpolicer:issueCitation', false, payload)
    if not response then
        TriggerEvent('t1ger_trafficpolicer:notify', Lang['citation_unknown_error'], 'error')
        return
    end

    if not response.success then
        TriggerEvent('t1ger_trafficpolicer:notify', response.error or Lang['citation_unknown_error'], 'error')
        return
    end

    TriggerEvent('t1ger_trafficpolicer:notify', Lang['citation_sent'])
    resetCitation()
    OpenCitationMain()
end

local function showCitationOffences(offences)
    local options = {}
    for _, entry in ipairs(offences) do
        options[#options + 1] = {
            title = string.format('%s [$%s]', entry.offence, formatFine(entry.fine)),
            description = entry.category,
            disabled = true
        }
    end

    if #options == 0 then
        options[1] = {
            title = Lang['no_offences_selected'],
            disabled = true
        }
    end

    lib.registerContext({
        id = 't1ger_citations_view_received',
        title = Lang['view_selected_offences'],
        menu = 't1ger_receive_citation',
        options = options
    })

    lib.showContext('t1ger_citations_view_received')
end

local function resolveCitation(signature, accept)
    local header = accept and Lang['confirm_sign_title'] or Lang['confirm_decline_title']
    local content = accept and Lang['confirm_sign_body'] or Lang['confirm_decline_body']

    local choice = lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = true,
        labels = {
            confirm = Lang['button_yes'],
            cancel = Lang['button_no']
        }
    })

    if choice == 'confirm' then
        TriggerServerEvent('t1ger_trafficpolicer:resolveCitation', signature, accept)
    end
end

RegisterNetEvent('t1ger_trafficpolicer:receiveCitation')
AddEventHandler('t1ger_trafficpolicer:receiveCitation', function(payload)
    local officerName = payload.officer and payload.officer.name or Lang['unknown_officer']
    local title = (Lang['receive_citation_title']):format(officerName)
    local options = {
        {
            title = (Lang['citation_total_label']):format(formatFine(payload.fine)),
            disabled = true
        }
    }

    if payload.note and payload.note ~= '' then
        options[#options + 1] = {
            title = Lang['citation_note'],
            description = payload.note,
            disabled = true
        }
    end

    options[#options + 1] = {
        title = Lang['view_selected_offences'],
        icon = 'fa-solid fa-eye',
        onSelect = function()
            showCitationOffences(payload.offences or {})
        end
    }

    options[#options + 1] = {
        title = Lang['sign_and_pay'],
        icon = 'fa-solid fa-pen',
        onSelect = function()
            resolveCitation(payload.signature, true)
        end
    }

    options[#options + 1] = {
        title = Lang['decline_citation'],
        icon = 'fa-solid fa-xmark',
        onSelect = function()
            resolveCitation(payload.signature, false)
        end
    }

    if payload.expires then
        local remaining = math.max(payload.expires - os.time(), 0)
        options[#options + 1] = {
            title = Lang['citation_signature_timer'],
            description = Lang['citation_seconds_left']:format(remaining),
            disabled = true
        }
    end

    lib.registerContext({
        id = 't1ger_receive_citation',
        title = title,
        options = options
    })

    lib.showContext('t1ger_receive_citation')
end)

