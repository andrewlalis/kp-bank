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

local function showStartMenu()
    drawFrame()
    g.drawTextCenter(term, W/2, 3, "Welcome to HandieBank ATM!", colors.green, colors.white)
    g.drawTextCenter(term, W/2, 4, "Insert your card below, or click to log in or create an account.", colors.black, colors.white)
end

showStartMenu()
