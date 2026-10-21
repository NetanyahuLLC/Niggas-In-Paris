--==================================================
-- LOAD UI MODULE FROM GITHUB
--==================================================
local UI_URL = "https://raw.githubusercontent.com/NetanyahuLLC/Niggas-In-Paris/refs/heads/main/ui.lua"

local downloadOK, source = pcall(function()
    return game:HttpGet(UI_URL)
end)
if not downloadOK then
    error("[Market Hub] Failed to download ui.lua:\n" .. tostring(source), 0)
end
if type(source) ~= "string" or not source:find("%S") then
    error("[Market Hub] GitHub returned an empty UI response.", 0)
end

local chunk, parseError = loadstring(source, "ui.lua")
if not chunk then
    error("[Market Hub] Downloaded ui.lua has a syntax error:\n" .. tostring(parseError), 0)
end

local executeOK, result = pcall(chunk)
if not executeOK then
    error("[Market Hub] ui.lua failed while executing:\n" .. tostring(result), 0)
end
if type(result) ~= "table" or type(result.new) ~= "function" then
    error("[Market Hub] ui.lua did not return a valid module with UI.new(options).", 0)
end
local UI = result

--==================================================
-- GAME SERVICES / CONFIGURATION
--==================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local stockFolder = player:WaitForChild("ShopStock")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EPOCH_SECONDS = 30
local UPDATE_INTERVAL = 1
local SOUND_FILE = "neverlose.wav"
local SOUND_VOLUME = 1

--==================================================
-- DATA HELPERS
--==================================================
local function number(value)
    local n = tonumber(value)
    if n and n == n and n ~= math.huge and n ~= -math.huge then
        return n
    end
end

local function formatNumber(value)
    local n = number(value)
    if not n then return "N/A" end
    if n % 1 == 0 then return tostring(math.floor(n)) end
    return string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
end

local function seconds(value)
    value = math.max(0, math.floor(value))
    if value >= 60 then
        return string.format("%dm %02ds", math.floor(value / 60), value % 60)
    end
    return tostring(value) .. "s"
end

local function priceOf(data)
    for _, key in ipairs({"cost", "Cost", "price", "Price"}) do
        local n = number(data[key])
        if n and n >= 0 then return n end
    end
end

local function sortedItems(dict)
    local items = {}
    if type(dict) ~= "table" then return items end

    for key, data in pairs(dict) do
        if type(data) == "table" then
            table.insert(items, {
                key = tostring(key),
                name = tostring(data.name or key),
                price = priceOf(data),
            })
        end
    end

    table.sort(items, function(a, b)
        if a.price == nil and b.price ~= nil then return false end
        if a.price ~= nil and b.price == nil then return true end

