local r = require("CommonRequire")
local log = r.log
local RouteController = require("flight/route/Controller")
local BufferedDB = require("storage/BufferedDB")
local FlightFSM = require("flight/FlightFSM")
local FC = require("flight/FlightCore")
local InputHandler = require("InputHandler")
local Settings = require("Settings")
require("version")

local Task = require("system/Task")

local settingLink = library.getLinkByName("routes")
local routeLink = library.getLinkByName("routes")

if not settingLink or not routeLink then
    log:Error("Link databank named 'routes'")
    unit.exit()
end

local settingsDb = BufferedDB.New(settingLink)
local routeDb = BufferedDB.New(routeLink)
local settings = Settings.New(settingsDb)

Task.New("Main", function()
    log:Info(APP_NAME)
    log:Info("v", APP_VERSION)

    settingsDb.BeginLoad()
    routeDb.BeginLoad()

    while not settingsDb:IsLoaded() or not routeDb:IsLoaded() do
        coroutine.yield()
    end

    local fsm = FlightFSM.New(settings)
    settings.Reload()
    local fc = FC(RouteController.Instance(routeDb), fsm)
    fc:ReceiveEvents()
    InputHandler.New(fc)
end).Then(function()
    log:Info("Ready.")
end).Catch(function(t)
    log:Error(t.Name(), t:Error())
end)
