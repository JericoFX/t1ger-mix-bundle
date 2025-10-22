Config = {}

Config.Debug = false
Config.RouteCacheTTL = 10 * 60 * 1000 -- cache delivery routes for 10 minutes
Config.RouteTimeout = 25 * 60 -- seconds before an active delivery expires
Config.CoordinateTolerance = 4.0

Config.BuyWithBank = true
Config.SalePercentage = 0.75
Config.CertificatePrice = 15000
Config.DepositInBank = true
Config.DamagePercent = 5
Config.DepositDamage = 10
Config.AddLevelAmount = 2
Config.JobBossGrade = 4

Config.Companies = {
    [1] = {
        id = 1,
        name = 'Davis Deliveries',
        price = 125000,
        jobName = 'delivery1',
        menu = vector3(-456.95, -2753.43, 6.0),
        spawn = vector4(-447.78, -2752.48, 6.0, 44.5),
        trailerSpawn = vector4(-455.47, -2732.51, 6.0, 225.12),
        forklift = { model = 'forklift', pos = vector4(-460.56, -2744.66, 6.0, 48.77) },
        deliveries = {
            low = {
                { vector3(-424.58, -2789.02, 5.0), vector3(-401.26, -2707.57, 5.0), vector3(-354.62, -2783.85, 6.0) },
                { vector3(-472.41, -2693.13, 6.0), vector3(-490.63, -2666.89, 6.0), vector3(-513.62, -2636.47, 6.0) }
            },
            medium = {
                { vector3(-325.74, -2698.24, 6.0), vector3(-299.88, -2649.52, 6.0), vector3(-315.51, -2598.91, 6.0) },
                { vector3(-348.32, -2483.75, 6.3), vector3(-341.21, -2400.63, 6.3), vector3(-332.58, -2324.25, 6.3) }
            },
            high = {
                { vector3(-229.12, -2406.85, 6.3), vector3(-150.61, -2150.72, 16.7), vector3(-84.42, -2087.13, 16.9) },
                { vector3(25.67, -2016.52, 18.0), vector3(117.04, -1985.37, 18.3), vector3(164.58, -1892.64, 23.0) }
            }
        }
    },
    [2] = {
        id = 2,
        name = 'La Puerta Logistics',
        price = 115000,
        jobName = 'delivery2',
        menu = vector3(-297.55, -2599.26, 6.2),
        spawn = vector4(-304.61, -2599.87, 6.0, 136.67),
        trailerSpawn = vector4(-319.42, -2603.78, 6.0, 136.49),
        forklift = { model = 'forklift', pos = vector4(-297.82, -2593.84, 6.0, 45.55) },
        deliveries = {
            low = {
                { vector3(-269.11, -2519.61, 6.0), vector3(-233.67, -2460.11, 6.0), vector3(-191.45, -2431.64, 6.0) },
                { vector3(-217.13, -2404.32, 6.0), vector3(-185.52, -2362.42, 6.0), vector3(-151.82, -2315.72, 6.0) }
            },
            medium = {
                { vector3(-117.81, -2242.59, 7.0), vector3(-73.45, -2180.13, 8.0), vector3(-17.82, -2136.21, 8.0) },
                { vector3(8.65, -2064.71, 17.5), vector3(58.77, -2005.24, 17.5), vector3(87.16, -1947.61, 20.0) }
            },
            high = {
                { vector3(147.57, -1875.13, 24.0), vector3(195.47, -1788.12, 28.9), vector3(231.18, -1712.46, 29.6) },
                { vector3(270.85, -1645.63, 29.6), vector3(316.87, -1567.42, 29.3), vector3(356.96, -1498.23, 29.3) }
            }
        }
    }
}

Config.JobValues = {
    low = {
        label = 'Local',
        level = 0,
        certificate = false,
        payout = { base = 550, perStop = 175 },
        vehicles = {
            { name = 'Surfer 2', model = 'surfer2', deposit = 500 },
            { name = 'Speedo', model = 'speedo', deposit = 1000 },
            { name = 'Burrito 3', model = 'burrito3', deposit = 1500 },
            { name = 'Rumpo', model = 'rumpo', deposit = 2000 }
        }
    },
    medium = {
        label = 'Regional',
        level = 20,
        certificate = false,
        payout = { base = 950, perStop = 250 },
        vehicles = {
            { name = 'Boxville 2', model = 'boxville2', deposit = 1500 },
            { name = 'Boxville 4', model = 'boxville4', deposit = 3000 }
        }
    },
    high = {
        label = 'Long Haul',
        level = 50,
        certificate = true,
        payout = { base = 1350, perStop = 375 },
        vehicles = {
            { name = 'Hauler', model = 'hauler', deposit = 1500 },
            { name = 'Packer', model = 'packer', deposit = 3000 },
            { name = 'Phantom', model = 'phantom', deposit = 4500 }
        }
    }
}

Config.BlipSettings = {
    company = { enable = true, sprite = 477, display = 4, scale = 0.60, color = 0, name = 'Delivery Company' }
}

Config.MarkerSettings = {
    menu = { enable = true, type = 20, scale = { x = 0.7, y = 0.7, z = 0.7 }, color = { r = 240, g = 52, b = 52, a = 100 } }
}

Config.Keybinds = {
    interact = 38 -- E
}
