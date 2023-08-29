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

local function tryLoginViaInput()
    drawFrame()
    g.drawTextCenter(term, W/2, 3, "Enter your username and password below.", colors.black, colors.white)
    g.drawText(term, 22, 5, "Username", colors.black, colors.white)
    g.drawXLine(term, 22, 40, 6, colors.lightGray)
    g.drawText(term, 22, 8, "Password", colors.black, colors.white)
    g.drawXLine(term, 22, 40, 9, colors.lightGray)

    g.fillRect(term, 22, 11, 9, 3, colors.green)
    g.drawTextCenter(term, W/2, 12, "Login", colors.white, colors.green)

    g.fillRect(term, 22, 15, 9, 3, colors.red)
    g.drawTextCenter(term, W/2, 16, "Cancel", colors.white, colors.red)

    local username = ""
    local password = ""
    local selectedInput = "username"
    while true do
        local usernameColor = colors.lightGray
        if selectedInput == "username" then usernameColor = colors.gray end
        g.drawXLine(term, 22, 40, 6, usernameColor)
        g.drawText(term, 22, 6, string.rep("*", #username), colors.white, usernameColor)

        local passwordColor = colors.lightGray
        if selectedInput == "password" then passwordColor = colors.gray end
        g.drawXLine(term, 22, 40, 9, passwordColor)
        g.drawText(term, 22, 9, string.rep("*", #password), colors.white, passwordColor)

        local event, p1, p2, p3 = os.pullEvent()
        if event == "char" then
            local char = p1
            if selectedInput == "username" and #username < 12 then
                username = username .. char
            elseif selectedInput == "password" and #password < 18 then
                password = password .. char
            end
        elseif event == "key" then
            local keyCode = p1
            local held = p2
            if keyCode == keys.backspace then
                if selectedInput == "username" and #username > 0 then
                    username = string.sub(username, 1, #username - 1)
                elseif selectedInput == "password" and #password > 0 then
                    password = string.sub(password, 1, #password - 1)
                end
            end
        elseif event == "mouse_click" then
            local button = p1
            local x = p2
            local y = p3
            if y == 6 and x >= 22 and x <= 40 then
                selectedInput = "username"
            elseif y == 9 and x >= 22 and x <= 40 then
                selectedInput = "password"
            elseif y >= 11 and y <= 13 and x >= 22 and x <= 30 then
                return {username = username, password = password}
            elseif y >= 15 and y <= 17 and x >= 22 and x <= 30 then
                return nil
            end
        end
    end
end

local function showLoginUI()
    while true do
        drawFrame()
        g.drawTextCenter(term, W/2, 3, "Welcome to HandieBank ATM!", colors.green, colors.white)
        g.drawTextCenter(term, W/2, 5, "Insert your card below, or click to login.", colors.black, colors.white)
        g.fillRect(term, 22, 7, 9, 3, colors.green)
        g.drawTextCenter(term, W/2, 8, "Login", colors.white, colors.green)
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
                local credentials = tryLoginViaInput()
                if credentials then return credentials end
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