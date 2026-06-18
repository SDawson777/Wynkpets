--[[
    TradeConfig.luau
    Trading system configuration.
]]

local TradeConfig = {}

TradeConfig.MaxPetsPerSide = 6
TradeConfig.TradeCooldown = 5 -- seconds between trades
TradeConfig.TradeTimeout = 60 -- seconds before auto-cancel
TradeConfig.MaxGemsPerTrade = 10000

return TradeConfig
