-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

Config = {}

Config.UseCashForPurchases = true -- true: pay with cash | false: pay with bank balance.
Config.ReceiveCashOnSale = true   -- true: receive cash when selling | false: receive bank deposit.
Config.TransactionCooldown = 5000 -- milliseconds before another transaction can be started.
Config.InteractDistance = 1.5     -- how close the player must be to interact with the shop.
Config.MarkerDrawDistance = 5.0   -- marker draw distance when enabled in the shop configuration.
Config.NotificationTitle = 'Pawn Shop'

Config.Pawnshops = {
    {
        coords = vector3(412.42, 314.41, 103.02),
        blip = {enable = true, name = 'Pawn Shop', sprite = 59, display = 4, scale = 0.65, color = 5},
        marker = {enable = true, type = 27, color = {r = 255, g = 255, b = 0, a = 100}, scale = vector3(1.0, 1.0, 1.0)},
        prompt = 'open_shop',
        keyBind = 38
    },
    {
        coords = vector3(182.76, -1319.38, 29.31),
        blip = {enable = true, name = 'Pawn Shop', sprite = 59, display = 4, scale = 0.65, color = 5},
        marker = {enable = true, type = 27, color = {r = 255, g = 255, b = 0, a = 100}, scale = vector3(1.0, 1.0, 1.0)},
        prompt = 'open_shop',
        keyBind = 38
    },
    {
        coords = vector3(-1459.34, -413.79, 35.73),
        blip = {enable = true, name = 'Pawn Shop', sprite = 59, display = 4, scale = 0.65, color = 5},
        marker = {enable = true, type = 27, color = {r = 255, g = 255, b = 0, a = 100}, scale = vector3(1.0, 1.0, 1.0)},
        prompt = 'open_shop',
        keyBind = 38
    }
}

Config.Items = {
    goldwatch = {
        label = 'Gold Watch',
        buy = {enabled = true, price = 1000},
        sell = {enabled = true, price = 500}
    },
    goldbar = {
        label = 'Gold Bar',
        buy = {enabled = true, price = 1000},
        sell = {enabled = true, price = 500}
    }
}
