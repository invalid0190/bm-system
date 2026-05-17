-- =============================================================================
-- SERVER DEALER LOCATION & SCHEDULE
-- =============================================================================

local ActiveDealerIndex = nil
local ActiveDealerLocation = nil
local LastRotation = 0
local LastOpenState = nil
local LastTimeModifierKey = nil

local function NormalizeDealerLocation(location, index)
    if not location then
        return nil
    end

    local coords = type(location) == 'table' and location.coords or nil
    coords = coords or location
    if not coords or not coords.x or not coords.y or not coords.z then
        return nil
    end

    return {
        index = index,
        label = BMString(type(location) == 'table' and location.label or nil, 'Unknown'),
        x = BMNumber(coords.x, 0.0),
        y = BMNumber(coords.y, 0.0),
        z = BMNumber(coords.z, 0.0),
        w = BMNumber(coords.w, 0.0)
    }
end

local function GetDealerLocations()
    local marketConfig = Config.BlackMarket or {}
    local locations = {}

    for index, location in ipairs(type(marketConfig.locations) == 'table' and marketConfig.locations or {}) do
        local normalized = NormalizeDealerLocation(location, index)
        if normalized then
            locations[#locations + 1] = normalized
        end
    end

    if #locations == 0 then
        local fallback = NormalizeDealerLocation(marketConfig.coords, 1)
        if fallback then
            locations[1] = fallback
        end
    end

    return locations
end

local function GetDealerHour()
    local schedule = Config.DealerSchedule or {}

    if schedule.useServerTime == false and type(GetClockHours) == 'function' then
        local ok, gameHour = pcall(GetClockHours)
        if ok then
            return BMInteger(gameHour, 0)
        end
    end

    return BMInteger(os.date('*t').hour, 0)
end

local function IsHourInWindow(hour, startHour, stopHour)
    hour = BMInteger(hour, 0)
    startHour = BMInteger(startHour, 0)
    stopHour = BMInteger(stopHour, 0)

    if startHour == stopHour then
        return true
    end

    if startHour < stopHour then
        return hour >= startHour and hour < stopHour
    end

    return hour >= startHour or hour < stopHour
end

function IsBlackMarketOpen()
    local schedule = Config.DealerSchedule or {}
    if schedule.enabled == false then
        return true
    end

    local openHours = type(schedule.openHours) == 'table' and schedule.openHours or {}
    if #openHours == 0 then
        return true
    end

    local hour = GetDealerHour()
    for _, window in ipairs(openHours) do
        if IsHourInWindow(hour, window.start, window.stop) then
            return true
        end
    end

    return false
end

local function SelectDealerLocation(force)
    if not IsBlackMarketOpen() then
        ActiveDealerLocation = nil
        ActiveDealerIndex = nil
        return nil
    end

    local locations = GetDealerLocations()
    if #locations == 0 then
        ActiveDealerLocation = nil
        ActiveDealerIndex = nil
        return nil
    end

    local schedule = Config.DealerSchedule or {}
    local rotationSeconds = BMInteger(schedule.rotationInterval, 60) * 60
    local shouldRotate = force
        or not ActiveDealerLocation
        or (rotationSeconds > 0 and os.time() - BMInteger(LastRotation, 0) >= rotationSeconds)

    if not shouldRotate then
        return ActiveDealerLocation
    end

    local nextIndex = math.random(1, #locations)
    if #locations > 1 and ActiveDealerIndex then
        local guard = 0
        while nextIndex == ActiveDealerIndex and guard < 10 do
            nextIndex = math.random(1, #locations)
            guard = guard + 1
        end
    end

    ActiveDealerIndex = nextIndex
    ActiveDealerLocation = locations[nextIndex]
    LastRotation = os.time()
    BMLog('INFO', 'Dealer moved to %s (%d).', BMString(ActiveDealerLocation.label, 'location'), ActiveDealerIndex)

    return ActiveDealerLocation
end

local function GetDealerState()
    local open = IsBlackMarketOpen()
    local location = open and SelectDealerLocation(false) or nil
    local schedule = Config.DealerSchedule or {}

    return {
        open = open,
        hour = GetDealerHour(),
        location = location,
        closedMessage = BMString(schedule.closedMessage, 'Dealer is not available right now.')
    }
end

local function BroadcastDealerState()
    TriggerClientEvent('blackmarket:client:dealerStateChanged', -1, GetDealerState())
end

function GetCurrentDealerLocation()
    if not IsBlackMarketOpen() then
        return nil
    end

    return SelectDealerLocation(false)
end

function GetCurrentDealerCoords()
    local location = GetCurrentDealerLocation()
    if not location then return nil end

    return vector3(location.x, location.y, location.z)
end

function GetBlackMarketTimeModifier()
    local schedule = Config.DealerSchedule or {}
    local modifiers = type(schedule.timeModifiers) == 'table' and schedule.timeModifiers or {}
    local hour = GetDealerHour()

    for _, modifier in ipairs(modifiers) do
        if IsHourInWindow(hour, modifier.start, modifier.stop) then
            return modifier
        end
    end

    return {}
end

local function GetTimeModifierKey()
    local modifier = GetBlackMarketTimeModifier()

    return table.concat({
        BMString(modifier.start, 'default'),
        BMString(modifier.stop, 'default'),
        BMString(modifier.priceMultiplier, '1'),
        BMString(modifier.stockMultiplier, '1')
    }, ':')
end

function GetBlackMarketPriceMultiplier()
    return BMNumber(GetBlackMarketTimeModifier().priceMultiplier, 1.0)
end

function GetBlackMarketStockMultiplier()
    return BMNumber(GetBlackMarketTimeModifier().stockMultiplier, 1.0)
end

lib.callback.register('blackmarket:server:getDealerState', function()
    return GetDealerState()
end)

RegisterCommand('bm_dealer_rotate', function(source)
    if source ~= 0 then
        return
    end

    SelectDealerLocation(true)
    BroadcastDealerState()

    if type(ResetStock) == 'function' then
        ResetStock()
    end
end, true)

RegisterCommand('bm_dealer_status', function(source)
    local state = GetDealerState()
    local location = state.location
    local message = state.open and string.format(
        'Dealer open at %s (%.2f, %.2f, %.2f). Hour: %d',
        BMString(location and location.label, 'unknown'),
        BMNumber(location and location.x, 0.0),
        BMNumber(location and location.y, 0.0),
        BMNumber(location and location.z, 0.0),
        BMInteger(state.hour, 0)
    ) or string.format('Dealer closed. Hour: %d', BMInteger(state.hour, 0))

    if source == 0 then
        BMLog('INFO', message)
    else
        TriggerClientEvent('blackmarket:client:notify', source, 'Dealer Status', message, state.open and 'success' or 'error')
    end
end, true)

CreateThread(function()
    math.randomseed(os.time())
    Wait(2000)
    SelectDealerLocation(true)
    LastOpenState = IsBlackMarketOpen()
    LastTimeModifierKey = GetTimeModifierKey()
    BroadcastDealerState()

    while true do
        local schedule = Config.DealerSchedule or {}
        Wait(BMInteger(schedule.checkInterval, 60) * 1000)

        local wasOpen = LastOpenState
        local isOpen = IsBlackMarketOpen()
        local moved = false
        local modifierChanged = false

        if isOpen and not wasOpen then
            SelectDealerLocation(schedule.rotateLocationOnOpen ~= false or not ActiveDealerLocation)
            moved = ActiveDealerLocation ~= nil

            LastTimeModifierKey = GetTimeModifierKey()

            if type(ResetStock) == 'function' then
                ResetStock()
            end
        elseif isOpen then
            local previousIndex = ActiveDealerIndex
            SelectDealerLocation(false)
            moved = previousIndex ~= ActiveDealerIndex

            local modifierKey = GetTimeModifierKey()
            modifierChanged = modifierKey ~= LastTimeModifierKey
            LastTimeModifierKey = modifierKey
        else
            ActiveDealerLocation = nil
            ActiveDealerIndex = nil
            LastTimeModifierKey = nil
        end

        if wasOpen ~= isOpen or moved then
            LastOpenState = isOpen
            BroadcastDealerState()
        end

        if isOpen and moved and wasOpen and type(ResetStock) == 'function' then
            ResetStock()
        end

        if isOpen and modifierChanged and type(UpdatePrices) == 'function' then
            UpdatePrices()
        end
    end
end)

exports('isBlackMarketOpen', IsBlackMarketOpen)
exports('getCurrentDealerLocation', GetCurrentDealerLocation)
exports('getCurrentDealerCoords', GetCurrentDealerCoords)
