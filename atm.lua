--[[
atm.lua is a client program that runs on a computer connected to a backing
currency supply, to facilitate deposits and withdrawals as well as other
banking actions.

Each ATM keeps a secret security key that it uses to authorize secure actions
like recording transactions.
]]--

local g = require("simple-graphics")
local bankClient = require("bank-client")

local W, H = term.getSize()

local function drawFrame()
    g.clear(term, colors.white)
    g.drawXLine(term, 1, W, 1, colors.black)
    g.drawText(term, 2, 1, "ATM", colors.white, colors.black)
end

local function tryReadDiskCredentials(name)
    if disk.hasData(name) then
        local dataFile = fs.combine(disk.getMountPath(name), "bank-credentials.json")
        if fs.exists(dataFile) then
            local f = io.open(dataFile, "r")
            local content = textutils.unserializeJSON(f:read("*a"))
            f:close()
            if (
                content ~= nil and
                content.username and
                type(content.username) == "string" and
                content.password and
                type(content.password) == "string"
            ) then
                return content
            end
        end
    end
    return nil
end

local function showLoginUI()
    drawFrame()
    g.drawTextCenter(term, W/2, 3, "Welcome to HandieBank ATM!", colors.green, colors.white)
    g.drawTextCenter(term, W/2, 5, "Insert your card below, or click to login.", colors.black, colors.white)
    g.fillRect(term, 22, 7, 9, 3, colors.green)
    g.drawTextCenter(term, W/2, 8, "Login", colors.white, colors.green)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "disk" then
            local credentials = tryReadDiskCredentials(p1)
            if credentials then
                return credentials
            else
                disk.eject(p1)
            end
        elseif event == "mouse_click" then
            local button = p1
            local x = p2
            local y = p3
            if button == 1 and x >= 22 and x <= 30 and y >= 7 and y <= 9 then
                -- TODO: Show login input elements.
                return {username = "bleh", password = "bleh"}
            end
        end
    end
end

while true do
    local credentials = showLoginUI()
    g.clear(term, colors.black)
    print("Credentials: " .. textutils.serialize(credentials))
    return
end