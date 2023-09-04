local Container        = require("element/Container")
local ContainerTalents = require("element/ContainerTalents")
local Stopwatch        = require("system/Stopwatch")
local Task             = require("system/Task")
local Vec2             = require("native/Vec2")
local log              = require("debug/Log").Instance()
local pub              = require("util/PubSub").Instance()
local _                = require("util/Table")

---@alias FuelTankInfo {name:string, factorBar:Vec2, percent:number, visible:boolean, type:string}

---@class Fuel
---@field Instance fun():Fuel

local Fuel             = {}
Fuel.__index           = Fuel
local instance

---@param settings Settings
---@return Fuel
function Fuel.New(settings)
    if instance then
        return instance
    end

    local talents = ContainerTalents.New(
        settings.Number("containerProficiency", 0),
        settings.Number("fuelTankOptimization", 0),
        settings.Number("containerOptimization", 0),
        settings.Number("atmoFuelTankHandling", 0),
        settings.Number("spaceFuelTankHandling", 0),
        settings.Number("rocketFuelTankHandling", 0))

    local s = {}

    Task.New("FuelMonitor", function()
        local sw = Stopwatch.New()
        sw.Start()

        local fuelTanks = {
            atmo = Container.GetAllCo(ContainerType.Atmospheric),
            space = Container.GetAllCo(ContainerType.Space),
            rocket = Container.GetAllCo(ContainerType.Rocket)
        }

        while true do
            if sw.IsRunning() and sw.Elapsed() < 2 then
                coroutine.yield()
            else
                local byType = {} ---@type table<string,FuelTankInfo[]>

                for fuelType, tanks in pairs(fuelTanks) do
                    for _, tank in ipairs(tanks) do
                        local factor = tank.FuelFillFactor(talents)
                        local curr = {
                            name = tank.Name(),
                            factorBar = Vec2.New(1, factor),
                            percent = factor * 100,
                            visible = true,
                            type = fuelType
                        }

                        local bt = byType[fuelType] or {}
                        bt[#bt + 1] = curr
                        byType[fuelType] = bt
                    end

                    -- Sort tanks for HUD in alphabetical order
                    if byType[fuelType] then
                        table.sort(byType[fuelType], function(a, b)
                            return a.name < b.name
                        end)
                    end
                end

                pub.Publish("FuelByType", DeepCopy(byType))

                -- Now populate for the screen
                local fuelForScreen = {} ---@type {path:string, tank:FuelTankInfo}[]

                -- Sort tanks for screen based on acending fuel levels
                for fuelType, tanks in pairs(byType) do
                    table.sort(tanks, function(a, b) return a.percent < b.percent end)

                    for i, curr in ipairs(tanks) do
                        fuelForScreen[#fuelForScreen + 1] = {
                            path = string.format("fuel/%s/%d", fuelType, i),
                            tank = curr
                        }
                    end
                end

                pub.Publish("FuelData", fuelForScreen)

                sw.Restart()
            end
        end
    end).Then(function(...)
        log.Info("No fuel tanks detected")
    end).Catch(function(t)
        log.Error(t.Name(), t.Error())
    end)

    settings.RegisterCallback("containerProficiency", function(value)
        talents.ContainerProficiency = value
    end)

    settings.RegisterCallback("fuelTankOptimization", function(value)
        talents.FuelTankOptimization = value
    end)

    settings.RegisterCallback("containerOptimization", function(value)
        talents.ContainerOptimization = value
    end)

    settings.RegisterCallback("atmoFuelTankHandling", function(value)
        talents.AtmoFuelTankHandling = value
    end)

    settings.RegisterCallback("spaceFuelTankHandling", function(value)
        talents.SpaceFuelTankHandling = value
    end)

    settings.RegisterCallback("rocketFuelTankHandling", function(value)
        talents.RocketFuelTankHandling = value
    end)

    instance = setmetatable(s, Fuel)
    return instance
end

return Fuel
