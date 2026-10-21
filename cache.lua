local CACHE_FILE = "lezor_settings.json"

local Cache = {}

function Cache.load()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return {}
    end
    local ok, data = pcall(function()
        if not isfile(CACHE_FILE) then return nil end
        return readfile(CACHE_FILE)
    end)
    if not ok or type(data) ~= "string" or not data:find("%S") then
        return {}
    end
    local okJ, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(data)
    end)
    if okJ and type(result) == "table" then
        return result
    end
    return {}
end

function Cache.save(settings)
    if type(writefile) ~= "function" then return false end
    local okJ, data = pcall(function()
        return game:GetService("HttpService"):JSONEncode(settings)
    end)
    if not okJ or type(data) ~= "string" then return false end
    local ok = pcall(function() writefile(CACHE_FILE, data) end)
    return ok == true
end

return Cache
