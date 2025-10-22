-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 

Config = {
        Debug = true, -- allows you to restart script while in-game, otherwise u need to restart fivem.
    ProgressBars = true, -- set to false if you do not use progressBars or using your own
        T1GER_Keys = true, -- true/false whether you own or not own t1ger-keys
        T1GER_Shops = true, -- true/false whether you own or not own t1ger-shops
        BuyWithBank = true, -- buy company with bank money, false = cash.
        SalePercentage = 0.75, --
        CertificatePrice = 15000, -- Set price to purchase certificate
        DepositInBank = true, -- set to false to pay vehicle deposit with cash money
        DamagePercent = 5, -- if job veh body health is decreased more than 5%, then no payout for that specific delivery.
        DepositDamage = 10, -- if vehicle is damaged more than x %, then deposit is not returned.
        AddLevelAmount = 2, -- Set amount of levels added upon completing a job

        SocietyVehicleStorage = {
                table = 'player_vehicles',
                jobColumn = 'job',
                propsColumn = 'mods',
                stateColumn = 'state',
                availableState = 1
        }
}

Config.Companies = {
	[1] = {
		society = 'delivery1', -- this must match an identifier name inside Config.Society!
		price = 125000, -- price of the company.
		owned = false, -- do not touch this!
		menu = vector3(-456.95,-2753.43,6.0), -- menu pos
		spawn = vector4(-447.78,-2752.48,6.0,44.5), -- pos for veh spawn
		trailerSpawn = vector4(-455.47,-2732.51,6.0,225.12), -- pos to spawn trailer

		refill = {
			pos = vector3(-461.94,-2744.51,6.0), -- refill pos
			marker = {dist = 10.0, type = 27, scale = {x=3.0,y=3.0,z=1.0}, color = {r=220,g=60,b=60,a=100}}, -- refill marker
		},

		cargo = {
			pos = {
				[1] = vector3(-463.09,-2748.91,6.0),
				[2] = vector3(-465.1,-2747.12,6.0),
				[3] = vector3(-465.09,-2751.86,6.0),
				[4] = vector3(-467.06,-2749.3,6.0),
				[5] = vector3(-467.04,-2746.15,6.0),
			},
			marker = {dist = 15.0, type = 20, scale = {x=0.3,y=0.3,z=0.3}, color = {r=220,g=60,b=60,a=100}}, -- cargo marker
		},

		forklift = {
			model = 'forklift', -- forklift model
			pos = vector4(-460.56,-2744.66,6.0,48.77),
		},
	},
	[2] = {
		society = 'delivery2', -- this must match an identifier name inside Config.Society!
		price = 115000, -- price of the company.
		owned = false, -- do not touch this!
		menu = vector3(-297.55,-2599.26,6.2), -- menu pos
		spawn = vector4(-304.61,-2599.87,6.0,136.67), -- pos for veh spawn
		trailerSpawn = vector4(-319.42,-2603.78,6.0,136.49), -- pos to spawn trailer

		refill = {
			pos = vector3(-288.16,-2593.52,6.0), -- refill pos
			marker = {dist = 10.0, type = 27, scale = {x=3.0,y=3.0,z=1.0}, color = {r=220,g=60,b=60,a=100}}, -- refill marker
		},

		cargo = {
			pos = {
				[1] = vector3(-288.17,-2599.62,6.0),
				[2] = vector3(-290.12,-2601.57,6.03),
				[3] = vector3(-291.68,-2603.45,6.03),
				[4] = vector3(-290.6,-2597.05,6.0),
				[5] = vector3(-292.67,-2594.93,6.0),
			},
			marker = {dist = 15.0, type = 20, scale = {x=0.3,y=0.3,z=0.3}, color = {r=220,g=60,b=60,a=100}}, -- cargo marker
		},

		forklift = {
			model = 'forklift', -- forklift model
			pos = vector4(-297.82,-2593.84,6.0,45.55),
		},
	},
}

-- Blip Settings:
Config.BlipSettings = {
	['company'] = { enable = true, sprite = 477, display = 4, scale = 0.60, color = 0, name = "Delivery Company" },
}
-- Marker Settings:
Config.MarkerSettings = {
	['menu'] = { enable = true, type = 20, scale = {x = 0.7, y = 0.7, z = 0.7}, color = {r = 240, g = 52, b = 52, a = 100} },
	['delivery'] = { enable = true, type = 2, scale = {x = 0.35, y = 0.35, z = 0.35}, color = {r = 220, g = 60, b = 60, a = 100} },
}

Config.Society = { -- configure qb-management access for each delivery company
	['delivery1'] = {
		-- register society:
		name = 'delivery1', -- job name 
		label = 'Delivery Job', -- job label
                account = 'society_delivery1', -- society account
                datastore = 'society_delivery1', -- society datastore
                inventory = 'society_delivery1', -- society inventory
                boss_grade = 1, -- boss grade number to apply upon purchase
                bossMenuEvent = 'qb-bossmenu:client:OpenMenu', -- event to open boss menu
                data = {type = 'private'},
		-- settings:
		withdraw  = true, -- boss can withdraw money from account
		deposit   = true, -- boss can deposit money into account
		wash      = false, -- boss can wash money
		employees = true, -- boss can manage & recruit employees
		grades    = false -- boss can adjust all salaries for each job grade
	},
	['delivery2']  = {
		-- register society:
		name = 'delivery2', -- job name 
		label = 'Delivery Job', -- job label
                account = 'society_delivery2', -- society account
                datastore = 'society_delivery2', -- society datastore
                inventory = 'society_delivery2', -- society inventory
                boss_grade = 1, -- boss grade number to apply upon purchase
                bossMenuEvent = 'qb-bossmenu:client:OpenMenu', -- event to open boss menu
		data = {type = 'private'},
		-- settings:
		withdraw  = true, -- boss can withdraw money from account
		deposit   = true, -- boss can deposit money into account
		wash      = false, -- boss can wash money
		employees = true, -- boss can manage & recruit employees
		grades    = false -- boss can adjust all salaries for each job grade
	},
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
