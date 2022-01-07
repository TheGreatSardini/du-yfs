local lu = require("luaunit")
local FlightCore = require("FlightCore")
local EngineGroup = require("EngineGroup")
local vec3 = require("builtin/cpml/vec3")
local Pid = require("builtin/cpml/pid")


Test = {}

local fc = FlightCore()

function Test:testAcceleration()
    local all = EngineGroup("ALL")
    fc:Flush()
end

function Test:testPid()
    local pid = Pid(0, 0, 1)

    for i = 1, 100, .1 do
        local input = math.sin(i)
        pid:inject(input)
        io.write(input .. ": ".. tostring(pid:get() .. "\n"))
    end

end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
