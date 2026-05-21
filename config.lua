Config = {}

-- =============================================================================
-- BLACK MARKET LOCATION & NPC
-- =============================================================================

Config.BlackMarket = {
    -- Location Mode: 'random' (rotates between locations list below) or 'static' (stays fixed at coords below)
    locationMode = 'static',

    -- Secret fallback / static location coordinates
    coords = vec4(692.94, -1013.27, 22.71, 357.75), -- Hidden La Mesa warehouse back door
    locations = {
        { label = 'La Mesa warehouse', coords = vec4(712.65, -963.73, 30.4, 291.93) },
        { label = 'Cypress storage yard', coords = vec4(981.74, -147.36, 74.24, 36.47) },
        { label = 'Davis back alley', coords = vec4(170.4, -1799.05, 29.24, 318.21) },
        { label = 'La Puerta scrapyard', coords = vec4(-434.17, -1726.86, 18.84, 343.11) },
        { label = 'Vespucci service lane', coords = vec4(-1143.08, -1518.71, 7.55, 129.94) }
    },
    npcModel = `g_m_m_chicold_01`, -- Gang member model
    targetDistance = 2.5,
    serverValidationDistance = 5.0, -- Server-side anti-cheat distance for buy/sell events
    npc = {
        alpha = 255,
        scenario = 'WORLD_HUMAN_SMOKING',
        spawnTimeout = 5000,
        groundCheckAttempts = 25
    },
    blip = {
        enabled = false, -- Keep it secret - no blip by default
        sprite = 466,
        color = 1,
        scale = 0.8,
        name = '???'
    }
}


-- PROP SYSTEM


Config.Props = {
    enabled = true,
    loadTimeout = 5000,
    progress = {
        enabled = true,
        duration = 900,
        label = 'Setting up the drop...'
    },
    shopCrate = {
        enabled = true,
        model = 'bm-wooden-crate',
        forwardOffset = 0.65,
        sideOffset = 1.05,
        zOffset = 0.0,
        removeDistance = 8.0
    },
    purchase = {
        enabled = true,
        duration = 2500,
        label = 'Sealing the deal...',
        forwardOffset = 0.95,
        sideOffset = -0.45,
        zOffset = 0.00,
        weaponModel = 'bm-weapon-briefcase',
        stashModel = 'bm-metal_stash',
        stashCategories = {
            drugs = true,
            stolen = true,
            contraband = true
        }
    },
    tradeBag = {
        enabled = true,
        models = { 'bm-duffbag' },
        bone = 57005, -- SKEL_R_Hand
        offset = vector3(0.15, 0.03, -0.02),
        rotation = vector3(-90.0, 0.0, 0.0),
        dropDuration = 1200
    }
}

-- =============================================================================
-- DEALER SCHEDULE
-- =============================================================================

Config.DealerSchedule = {
    enabled = true,
    useServerTime = true, -- true = real server hour, false = GTA clock when available
    checkInterval = 60, -- seconds
    rotationInterval = 60, -- minutes while open
    rotateLocationOnOpen = true,
    closedMessage = 'Dealer is laying low. Come back at night.',
    openHours = {
        { start = 20, stop = 6 } -- 8 PM to 6 AM
    },
    timeModifiers = {
        { start = 20, stop = 23, priceMultiplier = 1.10, stockMultiplier = 1.00 },
        { start = 23, stop = 3, priceMultiplier = 1.25, stockMultiplier = 0.80 },
        { start = 3, stop = 6, priceMultiplier = 1.15, stockMultiplier = 0.65 }
    }
}

-- =============================================================================
-- DEALER TRUST DIALOGUE
-- =============================================================================
Config.DealerDialogue = {
    enabled = true,
    showInMainMenu = true,
    fallbackLine = "Eyes forward. Mouth shut. That is how you walk out of here.",
    noStockLine = "Shelves are dry. Check back when the heat dies down.",
    levels = {
        {
            minCred = 0,
            lines = {
                "Nobody vouched for you. That means you get nothing I cannot afford to lose.",
                "Fresh face means fresh risk. Buy small, disappear fast.",
                "I do not do favours for strangers. Pay up or walk.",
                "You are unknown. Unknown gets the bottom shelf and no questions answered."
            }
        },
        {
            minCred = 10,
            lines = {
                "You came back. That already puts you ahead of most.",
                "Still watching you. But you have not done anything stupid yet.",
                "Small history is better than none. Do not ruin it.",
                "I remember faces. Yours is starting to mean something small."
            }
        },
        {
            minCred = 25,
            lines = {
                "Word got back to me. You handled that quietly. Good.",
                "You move without making noise. That is rarer than you think.",
                "Twenty-five in the streets means you survived something. Respect that.",
                "I can give you a little more. Do not make it a habit to ask for more than that."
            }
        },
        {
            minCred = 50,
            lines = {
                "Half the city does not make it this far without burning someone. You did.",
                "Better access, better product, same rules. Do not forget the rules.",
                "You are worth the risk now. That is not a compliment I hand out easy.",
                "Fifty cred means you know how to keep your mouth shut. Prove I am right."
            }
        },
        {
            minCred = 75,
            lines = {
                "People ask about you now. I tell them you are solid. Do not make me a liar.",
                "You want the good stuff? It is behind the counter. You have earned a look.",
                "Seventy-five is where loyalty gets tested. Stay clean.",
                "High trust is a two-edged thing. You fall from here, you fall hard."
            }
        },
        {
            minCred = 90,
            lines = {
                "There are maybe four people I trust at this level. You know what happened to the other three.",
                "Top access. No limits. No second chances either.",
                "You are the kind of quiet that keeps everyone alive. I respect that.",
                "Say nothing, take what you need, leave no trail. You already know this."
            }
        }
    }
}

-- =============================================================================
-- ILLEGAL ITEMS FOR SALE
-- =============================================================================

Config.Items = {
    -- WEAPONS
    {
        name = 'WEAPON_PISTOL',
        label = 'Pistol (No Serial)',
        category = 'weapons',
        basePrice = 2500,
        minPrice = 1500,
        maxPrice = 4000,
        baseStock = 5,
        minStock = 1,
        maxStock = 10,
        requiredCred = 0, -- Minimum street cred needed
        priceVariance = 0.3 -- 30% variance
    },
    {
        name = 'WEAPON_SMG',
        label = 'SMG (Hot)',
        category = 'weapons',
        basePrice = 7500,
        minPrice = 5000,
        maxPrice = 12000,
        baseStock = 2,
        minStock = 0,
        maxStock = 5,
        requiredCred = 20,
        priceVariance = 0.35
    },
    {
        name = 'WEAPON_CARBINERIFLE',
        label = 'Carbine Rifle (Stolen)',
        category = 'weapons',
        basePrice = 15000,
        minPrice = 10000,
        maxPrice = 25000,
        baseStock = 1,
        minStock = 0,
        maxStock = 3,
        requiredCred = 50,
        priceVariance = 0.4
    },
    {
        name = 'WEAPON_KNIFE',
        label = 'Combat Knife',
        category = 'weapons',
        basePrice = 500,
        minPrice = 300,
        maxPrice = 800,
        baseStock = 10,
        minStock = 5,
        maxStock = 20,
        requiredCred = 0,
        priceVariance = 0.2
    },
    {
        name = 'WEAPON_BAT',
        label = 'Baseball Bat',
        category = 'weapons',
        basePrice = 200,
        minPrice = 100,
        maxPrice = 400,
        baseStock = 15,
        minStock = 5,
        maxStock = 25,
        requiredCred = 0,
        priceVariance = 0.25
    },

    -- DRUGS
    {
        name = 'weed_bag',
        label = 'Weed Bag',
        category = 'drugs',
        basePrice = 150,
        minPrice = 100,
        maxPrice = 250,
        baseStock = 20,
        minStock = 10,
        maxStock = 40,
        requiredCred = 0,
        priceVariance = 0.3
    },
    {
        name = 'cocaine',
        label = 'Cocaine',
        category = 'drugs',
        basePrice = 500,
        minPrice = 350,
        maxPrice = 800,
        baseStock = 10,
        minStock = 3,
        maxStock = 20,
        requiredCred = 15,
        priceVariance = 0.35
    },
    {
        name = 'meth',
        label = 'Methamphetamine',
        category = 'drugs',
        basePrice = 800,
        minPrice = 500,
        maxPrice = 1200,
        baseStock = 8,
        minStock = 2,
        maxStock = 15,
        requiredCred = 30,
        priceVariance = 0.4
    },
    {
        name = 'oxy',
        label = 'Oxycontin',
        category = 'drugs',
        basePrice = 300,
        minPrice = 200,
        maxPrice = 500,
        baseStock = 15,
        minStock = 5,
        maxStock = 30,
        requiredCred = 10,
        priceVariance = 0.3
    },

    -- STOLEN GOODS
    {
        name = 'stolen_phone',
        label = 'Stolen Phone',
        category = 'stolen',
        basePrice = 400,
        minPrice = 250,
        maxPrice = 600,
        baseStock = 12,
        minStock = 5,
        maxStock = 25,
        requiredCred = 0,
        priceVariance = 0.25
    },
    {
        name = 'stolen_jewelry',
        label = 'Stolen Jewelry',
        category = 'stolen',
        basePrice = 800,
        minPrice = 500,
        maxPrice = 1200,
        baseStock = 8,
        minStock = 2,
        maxStock = 15,
        requiredCred = 5,
        priceVariance = 0.35
    },
    {
        name = 'stolen_laptop',
        label = 'Stolen Laptop',
        category = 'stolen',
        basePrice = 600,
        minPrice = 400,
        maxPrice = 900,
        baseStock = 6,
        minStock = 2,
        maxStock = 12,
        requiredCred = 5,
        priceVariance = 0.3
    },
    {
        name = 'stolen_watch',
        label = 'Luxury Watch (Hot)',
        category = 'stolen',
        basePrice = 2500,
        minPrice = 1500,
        maxPrice = 4000,
        baseStock = 3,
        minStock = 0,
        maxStock = 8,
        requiredCred = 25,
        priceVariance = 0.4
    },

    -- CONTRABAND
    {
        name = 'lockpick',
        label = 'Lockpick Set',
        category = 'contraband',
        basePrice = 300,
        minPrice = 200,
        maxPrice = 500,
        baseStock = 20,
        minStock = 10,
        maxStock = 40,
        requiredCred = 0,
        priceVariance = 0.25
    },
    {
        name = 'armor',
        label = 'Body Armor',
        category = 'contraband',
        basePrice = 1500,
        minPrice = 1000,
        maxPrice = 2500,
        baseStock = 5,
        minStock = 2,
        maxStock = 10,
        requiredCred = 15,
        priceVariance = 0.3
    },
    {
        name = 'radio',
        label = 'Encrypted Radio',
        category = 'contraband',
        basePrice = 500,
        minPrice = 300,
        maxPrice = 800,
        baseStock = 10,
        minStock = 5,
        maxStock = 20,
        requiredCred = 10,
        priceVariance = 0.25
    }
}

-- =============================================================================
-- STOCK SYSTEM SETTINGS
-- =============================================================================

Config.Stock = {
    resetInterval = 30, -- Minutes between stock resets
    priceUpdateInterval = 15, -- Minutes between price fluctuations
    demandMultiplier = 1.5, -- Price multiplier when stock is low
    supplyMultiplier = 0.8 -- Price multiplier when stock is high
}

-- =============================================================================
-- REPUTATION SYSTEM
-- =============================================================================

Config.Reputation = {
    maxCred = 100,
    startingCred = 0,
    
    -- Cred gains
    purchaseGain = {
        weapons = 3,
        drugs = 2,
        stolen = 1,
        contraband = 1
    },
    
    tradeGain = 2, -- Cred gained per successful player trade
    
    -- Price modifiers based on cred level
    priceModifiers = {
        {minCred = 0, modifier = 1.0},      -- No discount
        {minCred = 10, modifier = 0.95},    -- 5% discount
        {minCred = 25, modifier = 0.90},    -- 10% discount
        {minCred = 50, modifier = 0.85},    -- 15% discount
        {minCred = 75, modifier = 0.80},    -- 20% discount
        {minCred = 90, modifier = 0.75}     -- 25% discount
    }
}

-- =============================================================================
-- POLICE ALERT SYSTEM
-- =============================================================================

Config.Police = {
    alertRadius = 100.0, -- meters
    checkInterval = 1000, -- ms between checks during trades
    requireOnDuty = true,
    
    -- Job names that count as police
    policeJobs = {
        ['police'] = true,
        ['sheriff'] = true,
        ['state'] = true,
        ['fbi'] = true
    },

    -- Qbox/QBX job types that count as police
    policeJobTypes = {
        ['leo'] = true
    },
    
    -- Warning messages
    messages = {
        dangerDetected = 'WARNING: Police activity detected nearby!',
        tradeCancelled = 'Trade cancelled due to police presence.',
        safeToTrade = 'Area appears clear.'
    }
}

-- =============================================================================
-- DISPATCH INTEGRATION
-- =============================================================================

Config.Dispatch = {
    enabled = true,
    provider = 'auto', -- auto, ps-dispatch, cd_dispatch, core_dispatch, custom, none
    cooldown = 120, -- seconds between black market alerts
    locationFuzzRadius = 85.0, -- meters; dispatch receives an area, not exact dealer spot
    jobs = { 'police', 'sheriff' },
    jobTypes = { 'leo' }, -- ps-dispatch commonly uses job type entries
    customEvent = nil,
    customEventIsServer = false,
    blip = {
        sprite = 66,
        colour = 1,
        color = 1,
        scale = 1.2,
        time = 5,
        radius = 80,
        flashes = false
    },
    alerts = {
        purchase = {
            chance = 25,
            code = '10-66',
            codeName = 'blackmarket_purchase',
            title = 'Suspicious Exchange',
            message = 'Possible underground market activity reported nearby.',
            priority = 2
        },
        trade = {
            chance = 35,
            code = '10-66',
            codeName = 'blackmarket_trade',
            title = 'Suspicious Handoff',
            message = 'Possible illegal handoff reported nearby.',
            priority = 2
        }
    }
}

-- =============================================================================
-- DISGUISE SYSTEM
-- =============================================================================

Config.Disguise = {
    enabled = true,
    radius = 35.0,
    graceDistance = 7.5, -- Extra server-side tolerance for latency/desync
    fakeJob = {
        name = 'delivery',
        label = 'Delivery Driver',
        type = 'civilian',
        onduty = true
    }
}

-- =============================================================================
-- TRADING SYSTEM
-- =============================================================================

Config.Trading = {
    maxDistance = 5.0, -- Max distance between traders
    distanceGrace = 1.5, -- Extra server-side tolerance for sync differences
    cooldown = 30, -- Seconds after completed/cancelled trades
    requestCooldown = 10, -- Seconds between outgoing trade requests
    confirmTimeout = 60, -- Seconds to confirm trade
    maxItemsPerTrade = 10,
    logFile = 'trades.log'
}

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================

Config.Notify = {
    durations = {
        short = 3000,
        default = 5000,
        long = 8000
    }
}

-- =============================================================================
-- DEBUG
-- =============================================================================

Config.Debug = false
