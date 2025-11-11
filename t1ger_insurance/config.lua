-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

Config = {}

Config.Database = {
        table = 'player_vehicles',                        -- database table containing owned vehicles
        ownerColumn = 'citizenid',                        -- column that stores the owner identifier
        vehicleColumn = 'mods',                           -- column that stores the vehicle properties as JSON
        plateColumn = 'plate',                            -- column that stores the plate
        insuranceColumn = 'insurance',                    -- boolean/tinyint column used to store insurance state
        modelColumn = 'vehicle',                          -- optional column containing the spawn name/model (set to false when not available)
        priceLookup = {                                   -- optional price lookup for dynamic pricing (set to false to disable)
                table = 'vehicles',                       -- table that contains vehicle prices
                joinColumn = 'model',                     -- column used to match against modelColumn
                priceColumn = 'price'                     -- column storing vehicle price
        }
}

Config.BuyWithOnlineBrokers = true                      -- when enabled, players can only buy insurance if no brokers are on duty.

Config.Insurance = {

        job = {
                name = 'insurance',                      -- job name configured in qb-core
                sync_time = 1,                           -- minutes between broker sync broadcasts (minimum 1)
                requireDuty = true,                      -- count only brokers that are on duty
                managementAccount = 'insurance',         -- qb-management society account (set to false to disable deposits)
                menu = {
                        keybind = 167,                   -- default F6
                        command = 'insurance',
                        defaultKey = 'F6'
                }
        },

        company = {
                menuKey = 38,
                loadDist = 10.0,
                interactDist = 1.5,
                marker = {enable = true, drawDist = 10.0, type = 20, scale = {x = 0.5, y = 0.5, z = 0.5}, color = {r = 240, g = 52, b = 52, a = 100}},
                blip = {enable = true, sprite = 523, color = 3, label = 'Insurance', scale = 0.75, display = 4},
                points = {                                  -- interaction points (supports overrides for menuKey/loadDist/interactDist/marker)
                        { pos = {-291.38, -429.7, 30.24} }
                }
        },

        price = {
                establish = 20,                          -- percentage of vehicle price billed upfront (requires price lookup)
                subscription = 3,                        -- percentage of vehicle price billed periodically
                upfront = 2000,                          -- fallback upfront price when price lookup is missing
                payment = 150                            -- fallback subscription price
        },

        cooldowns = {
                buy = 2,                                 -- minutes between insurance purchases
                cancel = 2,                              -- minutes between cancellations
                claim = 5                                -- minutes between claim/lookups
        },

        cache = {
                owners = 2,                              -- minutes to cache owned vehicle lookups (set to 0 to disable)
                plates = 2                               -- minutes to cache plate lookups (set to 0 to disable)
        }

}
