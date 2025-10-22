-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

Config = {}

Config.Debug = false

Config.TruckRobbery = {
    cooldown = 30, -- minutes between runs per player

    police = {
        jobs = { 'police', 'lspd' },
        minCops = 2,
        notify = true,
        blip = {
            show = true,
            time = 30,
            radius = 50.0,
            alpha = 250,
            color = 5,
        }
    },

    computer = {
        pos = { 1275.68, -1710.32, 54.77 },
        heading = 302.12,
        blip = {
            enable = true,
            sprite = 47,
            display = 4,
            scale = 0.65,
            color = 5,
            label = 'Truck Robbery Job'
        },
        prompt = {
            icon = 'fa-solid fa-laptop-code',
            label = 'Hack security terminal'
        },
        hack = {
            useSkillCheck = true,
            sequence = { 'easy', 'medium', 'medium', 'medium' },
            fallbackDuration = 4500 -- milliseconds if skill check disabled
        },
        fees = {
            amount = 1000,
            account = 'bank' -- "bank" or "cash"
        },
        animation = {
            dict = 'mp_fbi_heist',
            clip = 'loop',
            flag = 30
        }
    },

    truck = {
        model = 'stockade',
        spawnDistance = 150.0,
        spawnTrigger = 120.0,
        maxPursuitDistance = 350.0
    },

    truckBlip = {
        sprite = 477,
        color = 5,
        display = 2,
        scale = 0.60,
        label = 'Armored Truck'
    },

    rob = {
        detonateTimer = 12,
        takeLootTimer = 10,
        bagProp = 'prop_cs_heist_bag_02',
        enableMoneyBag = true,
        progressIcon = 'fa-solid fa-vault'
    },

    reward = {
        money = { dirty = true, min = 1000, max = 5000 },
        items = {
            enable = true,
            list = {
                { item = 'goldbar', min = 1, max = 3, chance = 30 },
                { item = 'goldwatch', min = 1, max = 3, chance = 75 },
            }
        }
    }
}

Config.TruckSpawns = {
    {
        pos = { -1327.4797, -86.0453, 49.31 },
        heading = 160.0,
        security = {
            { ped = 's_m_m_security_01', seat = -1, weapon = 'WEAPON_SMG' },
            { ped = 's_m_m_security_01', seat = 0, weapon = 'WEAPON_PUMPSHOTGUN' },
            { ped = 's_m_m_security_01', seat = 1, weapon = 'WEAPON_SMG' }
        }
    },
    {
        pos = { -2075.8882, -233.7391, 21.10 },
        heading = 70.0,
        security = {
            { ped = 's_m_m_security_01', seat = -1, weapon = 'WEAPON_SMG' },
            { ped = 's_m_m_security_01', seat = 0, weapon = 'WEAPON_PUMPSHOTGUN' },
            { ped = 's_m_m_security_01', seat = 1, weapon = 'WEAPON_SMG' }
        }
    },
    {
        pos = { -972.1782, -1530.9045, 4.89 },
        heading = 55.0,
        security = {
            { ped = 's_m_m_security_01', seat = -1, weapon = 'WEAPON_SMG' },
            { ped = 's_m_m_security_01', seat = 0, weapon = 'WEAPON_PUMPSHOTGUN' },
            { ped = 's_m_m_security_01', seat = 1, weapon = 'WEAPON_SMG' }
        }
    },
    {
        pos = { 798.1843, -1799.8174, 29.33 },
        heading = 2.0,
        security = {
            { ped = 's_m_m_security_01', seat = -1, weapon = 'WEAPON_SMG' },
            { ped = 's_m_m_security_01', seat = 0, weapon = 'WEAPON_PUMPSHOTGUN' },
            { ped = 's_m_m_security_01', seat = 1, weapon = 'WEAPON_SMG' }
        }
    },
    {
        pos = { 1247.0719, -344.6563, 69.08 },
        heading = 250.0,
        security = {
            { ped = 's_m_m_security_01', seat = -1, weapon = 'WEAPON_SMG' },
            { ped = 's_m_m_security_01', seat = 0, weapon = 'WEAPON_PUMPSHOTGUN' },
            { ped = 's_m_m_security_01', seat = 1, weapon = 'WEAPON_SMG' }
        }
    }
}
