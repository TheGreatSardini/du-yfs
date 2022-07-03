local brakes = require("flight/Brakes")()
local checks = require("du-libs:debug/Checks")
local vehicle = require("du-libs:abstraction/Vehicle")()
local calc = require("du-libs:util/Calc")
local Velocity = vehicle.velocity.Movement

local state = {}
state.__index = state
local name = "CorrectDeviation"

local function new(fsm)
    checks.IsTable(fsm, "fsm", name .. ":new")

    local o = {
        fsm = fsm,
        limit = calc.Kph2Mps(3)
    }

    setmetatable(o, state)

    return o
end

function state:Enter()
end

function state:Leave()

end

function state:Flush(next, previous, chaseData)
    local brakeDistance, neededBrakeAcceleration = brakes:BrakeDistance(next:DistanceTo())

    if brakeDistance >= next:DistanceTo() or neededBrakeAcceleration > 0 then
        self.fsm:SetState(ApproachWaypoint(self.fsm))
    else
        brakes:Set(true)

        -- Come to a near stop before moving on
        local vel = Velocity()
        local speed = Velocity():len()

        if speed < self.limit then
            self.fsm:SetState(ReturnToPath(self.fsm))
        else
            -- As the velocity goes down, so does the adjustment
            local againstVel = -vel:normalize() * speed
            self.fsm:Thrust()
        end
    end
end

function state:Update()
end

function state:WaypointReached(isLastWaypoint, next, previous)
end

function state:Name()
    return name
end

return setmetatable(
        {
            new = new
        },
        {
            __call = function(_, ...)
                return new(...)
            end
        }
)