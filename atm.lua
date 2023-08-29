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

local function showLoginUI()
    drawFrame()
    g.drawTextCenter(term, W/2, 3, "Welcome to HandieBank ATM!", colors.green, colors.white)
    g.drawTextCenter(term, W/2, 4, "Insert your card below, or click to login.", colors.black, colors.white)
    g.fillRect(term, W/2 - 3, 7, 7, 3, colors.lightGray)
    g.drawTextCenter(term, W/2, 8, "Login", colors.green, colors.lightGray)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "disk" then
            print("Disk: "..p1)
            return {username = "bleh", password = "bleh"}
        elseif event == "mouse_click" then
            local button = p1
            local x = p2
            local y = p3
            if button == 1 and x >= (W/2 - 3) and x <= (W/2 + 4) and y >= 7 and y <= 9 then
                return {username = "bleh", password = "bleh"}
            end
        end
    end
end

while true do
    local credentials = showLoginUI()
end