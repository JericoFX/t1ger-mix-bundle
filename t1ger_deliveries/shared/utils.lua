SharedUtils = SharedUtils or {}

local function copyVector(value)
    local valueType = type(value)

    if valueType == 'vector3' then
        return vector3(value.x, value.y, value.z)
    elseif valueType == 'vector4' then
        return vector4(value.x, value.y, value.z, value.w)
    end

    return nil
end

function SharedUtils.DeepCopy(value)
    if type(value) ~= 'table' then
        local vectorCopy = copyVector(value)
        return vectorCopy or value
    end

    local copy = {}

    for k, v in pairs(value) do
        copy[k] = SharedUtils.DeepCopy(v)
    end

    return copy
end

function SharedUtils.FormatCurrency(amount)
    amount = tonumber(amount) or 0
    local formatted = string.format('%d', math.floor(amount))

    local k
    while true do
        formatted, k = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end

    return formatted
end

function SharedUtils.GetTickCount()
    if IsDuplicityVersion() then
        return math.floor(os.time() * 1000)
    end

    return GetGameTimer()
end

function SharedUtils.GetCachedValue(cache, key, ttl, generator)
    cache[key] = cache[key] or {}

    local entry = cache[key]
    local now = SharedUtils.GetTickCount()

    if entry.value ~= nil and entry.expiresAt and entry.expiresAt > now then
        return entry.value
    end

    local value = generator()

    if ttl and ttl > 0 then
        entry.expiresAt = now + ttl
    else
        entry.expiresAt = nil
    end

    entry.value = value

    return value
end

function SharedUtils.VectorEquals(a, b, tolerance)
    if not a or not b then
        return false
    end

    tolerance = tolerance or 1.5

    local av = vector3(a.x, a.y, a.z)
    local bv = vector3(b.x, b.y, b.z)

    return #(av - bv) <= tolerance
end

function SharedUtils.GetCompany(companyId)
    return Config.Companies and Config.Companies[companyId]
end

function SharedUtils.GetAllowedVehicles(companyId)
    local allowed = {}
    local company = SharedUtils.GetCompany(companyId)

    if not company then
        return allowed
    end

    local function register(model)
        if type(model) == 'string' then
            allowed[string.lower(model)] = true
        end
    end

    if company.vehicles then
        for _, model in ipairs(company.vehicles) do
            register(model)
        end
    end

    if Config.JobValues then
        for _, tier in pairs(Config.JobValues) do
            if tier.vehicles then
                for _, vehicle in ipairs(tier.vehicles) do
                    register(vehicle.model or vehicle)
                end
            end
        end
    end

    return allowed
end

function SharedUtils.IsVehicleAllowed(companyId, model)
    if not model then return false end

    local allowed = SharedUtils.GetAllowedVehicles(companyId)
    return allowed[string.lower(model)] == true
end

function SharedUtils.IsAllowedDeliveryCoordinate(companyId, coords, tolerance)
    local company = SharedUtils.GetCompany(companyId)

    if not company or not company.deliveries then
        return false
    end

    tolerance = tolerance or Config.CoordinateTolerance or 3.0

    for _, tier in pairs(company.deliveries) do
        for _, route in ipairs(tier) do
            for _, point in ipairs(route) do
                if SharedUtils.VectorEquals(point, coords, tolerance) then
                    return true
                end
            end
        end
    end

    return false
end

return SharedUtils
