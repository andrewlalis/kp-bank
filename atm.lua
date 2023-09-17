--[[
atm.lua is a client program that runs on a computer connected to a backing
currency supply, to facilitate deposits and withdrawals as well as other
banking actions.

Each ATM keeps a secret security key that it uses to authorize secure actions
like recording transactions.
]]--

local g = require("simple-graphics")
local bankClient = require("bank-client")

-- The name of the peripheral where this ATM can draw money from.
local CURRENCY_SOURCE = "minecraft:barrel_0"
-- The name of the peripheral where this ATM can deposit money to.
local CURRENCY_SINK = "minecraft:barrel_1"
-- The name of the peripheral where this ATM interacts with the user.
local CURRENCY_BIN = "minecraft:barrel_2"

local BANK_HOST = "central-bank"
local SECURITY_KEY = "4514-1691-1660-7358-1884-0506-0878-7098-1511-3359-3602-3581-6910-0791-1843-5936"
local modem = peripheral.find("modem") or error("No modem attached.")
bankClient.init(peripheral.getName(modem), BANK_HOST, SECURITY_KEY)
if not peripheral.isPresent(CURRENCY_SOURCE) then error("No CURRENCY_SOURCE peripheral named \""..CURRENCY_SOURCE.."\" was found.") end
if not peripheral.isPresent(CURRENCY_SINK) then error("No CURRENCY_SINK peripheral named \""..CURRENCY_SINK.."\" was found.") end
if not peripheral.isPresent(CURRENCY_BIN) then error("No CURRENCY_BIN peripheral named \""..CURRENCY_BIN.."\" was found.") end

local W, H = term.getSize()

local function isCurrency(itemStack)
    return itemStack ~= nil and itemStack.name == "minecraft:sunflower" and itemStack.nbt == "1b95aea642a1b0e9624787ed7227cf35"
end

local function countCurrency(peripheralName)
    local inv = peripheral.wrap(peripheralName)
    if not inv then return 0 end
    local total = 0
    for slot, itemStack in pairs(inv.list()) do
        if isCurrency(itemStack) then total = total + itemStack.count end
    end
    return total
end

local function getFreeSpace(peripheralName)
    local inv = peripheral.wrap(peripheralName)
    if not inv then return 0 end
    local space = 0
    for i = 1, inv.size() do
        local itemStack = inv.getItemDetail(i)
        if itemStack == nil then
            space = space + 64
        elseif isCurrency(itemStack) then
            space = space + (64 - itemStack.count)
        end
    end
    return space
end

local function transferCurrency(fromName, toName, amount)
    local sourceInv = peripheral.wrap(fromName)
    local transferred = 0
    local attempts = 0
    while transferred < amount do
        local items = sourceInv.list()
        for slot, itemStack in pairs(items) do
            if isCurrency(itemStack) then
                local amountToTransfer = math.min(amount - transferred, itemStack.count)
                local actualTransferred = sourceInv.pushItems(toName, slot, amountToTransfer)
                transferred = transferred + actualTransferred
            end
        end
        attempts = attempts + 1
        if attempts > 10 and transferred < amount then
            return false, transferred
        end
    end
    return true, amount
end

local function shortId(account)
    return "*" .. string.sub(account.id, -5, -1)
end

local function isDigit(char)
    if #char ~= 1 then return false end
    local intValue = string.byte(char) - string.byte("0")
    return intValue >= 0 and intValue <= 9
end

local function drawFrame()
    g.clear(term, colors.white)
    g.drawXLine(term, 1, W, 1, colors.black)
    g.drawText(term, 2, 1, "ATM", colors.white, colors.black)
    if bankClient.loggedIn() then
        local txt = "Logged in as " .. bankClient.state.auth.username
        local len = #txt
        g.drawText(term, W-len, 1, "Logged in as", colors.lightGray, colors.black)
        g.drawText(term, W-len+13, 1, bankClient.state.auth.username, colors.yellow, colors.black)
    end
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
    g.drawText(term, 16, 5, "Username", colors.black, colors.white)
    g.drawXLine(term, 16, 34, 6, colors.lightGray)
    g.drawText(term, 16, 8, "Password", colors.black, colors.white)
    g.drawXLine(term, 16, 34, 9, colors.lightGray)

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
        g.drawXLine(term, 16, 34, 6, usernameColor)
        g.drawText(term, 16, 6, string.rep("*", #username), colors.white, usernameColor)

        local passwordColor = colors.lightGray
        if selectedInput == "password" then passwordColor = colors.gray end
        g.drawXLine(term, 16, 34, 9, passwordColor)
        g.drawText(term, 16, 9, string.rep("*", #password), colors.white, passwordColor)

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
            elseif keyCode == keys.tab and selectedInput == "username" then
                selectedInput = "password"
            elseif keyCode == keys.enter and selectedInput == "password" then
                return {username = username, password = password} -- Do login right away.
            end
        elseif event == "mouse_click" then
            local button = p1
            local x = p2
            local y = p3
            if y == 6 and x >= 16 and x <= 34 then
                selectedInput = "username"
            elseif y == 9 and x >= 16 and x <= 34 then
                selectedInput = "password"
            elseif y >= 11 and y <= 13 and x >= 22 and x <= 30 then
                return {username = username, password = password} -- Do login
            elseif y >= 15 and y <= 17 and x >= 22 and x <= 30 then
                return nil -- Cancel
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

local function checkCredentialsUI(credentials)
    drawFrame()
    g.drawTextCenter(term, W/2, 3, "Checking your credentials...", colors.black, colors.white)
    os.sleep(1)
    bankClient.logIn(credentials.username, credentials.password)
    local accounts, errorMsg = bankClient.getAccounts()
    if not accounts then
        bankClient.logOut()
        g.drawTextCenter(term, W/2, 5, errorMsg, colors.red, colors.white)
        os.sleep(2)
        return false
    end
    g.drawTextCenter(term, W/2, 5, "Authentication successful.", colors.green, colors.white)
    os.sleep(1)
    return true
end

local function currencyBinPreviewUpdater(x, y, fg, bg, delay)
    delay = delay or 1
    return function()
        while true do
            local amount = countCurrency(CURRENCY_BIN)
            g.drawXLine(term, x, x + 10, y, bg)
            g.drawText(term, x, y, tostring(amount), fg, bg)
            os.sleep(delay)
        end
    end
end

local function showDepositUI(account)
    drawFrame()
    g.drawTextCenter(term, W/2, 3, "Deposit HandieMarks to your account "..shortId(account)..".", colors.black, colors.white)
    g.drawTextCenter(term, W/2, 5, "Add currency to the bin, then click to continue.", colors.black, colors.white)

    g.drawText(term, 20, 8, "Amount to Deposit", colors.black, colors.white)
    
    local continueButtonCoords = g.drawButton(term, 20, 12, 11, 3, "Continue", colors.white, colors.green)
    local cancelButtonCoords = g.drawButton(term, 20, 16, 11, 3, "Cancel", colors.white, colors.red)

    local state = {cancel = false, doDeposit = false}
    parallel.waitForAny(
        currencyBinPreviewUpdater(20, 9, colors.orange, colors.gray, 0.5),
        function ()
            while true do
                local event, button, x, y = os.pullEvent("mouse_click")
                if button == 1 then
                    if g.isButtonPressed(x, y, continueButtonCoords) and countCurrency(CURRENCY_BIN) > 0 then
                        state.doDeposit = true
                        return
                    elseif g.isButtonPressed(x, y, cancelButtonCoords) then
                        state.cancel = true
                        return
                    end
                end
            end
        end
    )

    if state.cancel then return false end
    if state.doDeposit then
        local function tryReturnFundsInError(amount)
            local returnSuccess, returnAmount = transferCurrency(CURRENCY_SOURCE, CURRENCY_BIN, amount)
            if not returnSuccess then
                local missingAmount = amount - returnAmount
                g.appendAndDrawConsole(term, console, "Couldn't return all funds. You are still owed "..tostring(missingAmount).." $HMK. Please contact an administrator for assistance.", cx, cy)
                os.sleep(3)
            else
                g.appendAndDrawConsole(term, console, "Your funds have been returned to the bin. Please collect them.", cx, cy)
                os.sleep(3)
            end
        end
        -- Clear the buttons and show some status.
        g.fillRect(term, 1, W, 12, H-11, colors.white)
        local console = g.createConsole(W/2, H-11, colors.white, colors.black, "UP")
        local cx = W/2 - W/4
        local cy = 11
        local amount = countCurrency(CURRENCY_BIN)
        g.appendAndDrawConsole(term, console, "Making deposit with value of "..tostring(amount).." $HMK...", cx, cy)
        os.sleep(1)
        local success, actualAmount = transferCurrency(CURRENCY_BIN, CURRENCY_SINK, amount)
        if not success then
            g.appendAndDrawConsole(term, console, "Transfer failed! Actual transfer: "..tostring(actualAmount).." $HMK. Please contact an administrator to report the issue.", cx, cy)
            os.sleep(1)
            tryReturnFundsInError(actualAmount)
            return false
        end
        g.appendAndDrawConsole(term, console, "Transfer complete.", cx, cy)
        os.sleep(1)
        local tx, errorMsg = bankClient.recordTransaction(account.id, amount, "ATM deposit")
        if not tx then
            g.appendAndDrawConsole(term, console, "Failed to post transaction: " .. errorMsg, cx, cy)
            tryReturnFundsInError(amount)
            os.sleep(3)
            return false
        end
        g.appendAndDrawConsole(term, console, "Transaction posted to account.", cx, cy)
        os.sleep(2)
        return true
    end
end

local function showWithdrawUI(account)
    drawFrame()
    g.drawTextCenter(term, W/2, 3, "Withdraw HandieMarks from your account "..shortId(account)..".", colors.black, colors.white)
    g.drawTextCenter(term, W/2, 5, "Enter an amount to withdraw:", colors.black, colors.white)
    g.drawXLine(term, 20, 30, 6, colors.gray)
    g.drawTextCenter(term, W/2, 7, "(Current balance: "..tostring(account.balance).." $HMK)", colors.gray, colors.white)
    local continueButtonCoords = g.drawButton(term, 20, 12, 11, 3, "Continue", colors.white, colors.green)
    local cancelButtonCoords = g.drawButton(term, 20, 16, 11, 3, "Cancel", colors.white, colors.red)

    local inputValue = ""
    local function drawInputValue(val)
        g.drawXLine(term, 20, 30, 6, colors.gray)
        local amountColor = colors.orange
        local intValue = tonumber(val)
        if intValue ~= nil and intValue > account.balance then
            amountColor = colors.red
        end
        g.drawText(term, 20, 6, val, colors.orange, colors.gray)
    end
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "char" and isDigit(p1) and #inputValue < 10 then
            inputValue = inputValue .. p1
            drawInputValue(inputValue)
        elseif event == "key" and p1 == keys.backspace and #inputValue > 0 then
            inputValue = string.sub(inputValue, 1, #inputValue - 1)
            drawInputValue(inputValue)
        elseif event == "mouse_click" and p1 == 1 then
            local x = p2
            local y = p3
            local amount = tonumber(inputValue)
            if g.isButtonPressed(x, y, continueButtonCoords) and amount ~= nil and amount > 0 and amount <= account.balance then
                local function tryReclaimFundsInError(amount)
                    local returnSuccess, returnAmount = transferCurrency(CURRENCY_BIN, CURRENCY_SINK, amount)
                    if not returnSuccess then
                        g.appendAndDrawConsole(term, console, "Failed to reclaim funds. Please contact an administrator.", cx, cy)
                    end
                end
                -- Do withdrawal
                g.fillRect(term, 1, W, 12, H-11, colors.white)
                local console = g.createConsole(W/2, H-11, colors.white, colors.black, "UP")
                local cx = W/2 - W/4
                local cy = 11
                g.appendAndDrawConsole(term, console, "Making withdrawal of " .. tostring(amount) .. " $HMK from account " .. shortId(account) .. ".", cx, cy)
                os.sleep(1)
                local withdrawn = 0
                while withdrawn < amount do
                    local freeSpace = getFreeSpace(CURRENCY_BIN)
                    if freeSpace < 1 then
                        g.appendAndDrawConsole(term, console, "No space available in the bin. Please take some currency out to continue.", cx, cy)
                        while getFreeSpace(CURRENCY_BIN) < 1 do
                            g.appendAndDrawConsole(term, console, "Waiting for free space...", cx, cy)
                            os.sleep(3)
                        end
                    end
                    local amountToTransfer = math.min(freeSpace, amount - withdrawn)
                    local success, actualTransfer = transferCurrency(CURRENCY_SOURCE, CURRENCY_BIN, amountToTransfer)
                    withdrawn = withdrawn + actualTransfer
                    if not success then
                        -- Failure! Send the money back, if we can.
                        g.appendAndDrawConsole(term, console, "Transfer failed! Please contact an administrator to report the issue.", cx, cy)
                        os.sleep(3)
                        tryReclaimFundsInError(withdrawn)
                        return false
                    else
                        g.appendAndDrawConsole(term, console, "Transferred " .. tostring(actualTransfer) .. " $HMK.", cx, cy)
                        os.sleep(1)
                    end
                end
                local tx, errorMsg = bankClient.recordTransaction(account.id, amount * -1, "ATM withdrawal")
                if not tx then
                    g.appendAndDrawConsole(term, console, "Failed to post transaction: " .. errorMsg, cx, cy)
                    tryReclaimFundsInError(amount)
                    os.sleep(3)
                    return false
                end
                g.appendAndDrawConsole(term, console, "Transaction posted to account.", cx, cy)
                os.sleep(2)
                return true
            elseif g.isButtonPressed(x, y, cancelButtonCoords) then
                return false
            end
        end
    end
end

local function showAccountUI(account)
    while true do
        drawFrame()
        g.drawXLine(term, 1, W, 2, colors.gray)
        g.drawText(term, 2, 2, "Account: " .. account.name, colors.white, colors.gray)
        g.drawText(term, W-3, 2, "Back", colors.white, colors.blue)

        g.drawText(term, 2, 4, "ID", colors.gray, colors.white)
        g.drawText(term, 2, 5, account.id, colors.black, colors.white)
        g.drawText(term, 2, 7, "Name", colors.gray, colors.white)
        g.drawText(term, 2, 8, account.name, colors.black, colors.white)
        g.drawText(term, 2, 10, "Balance ($HMK)", colors.gray, colors.white)
        g.drawText(term, 2, 11, tostring(account.balance), colors.orange, colors.white)

        local buttons = {}
        buttons.deposit = g.drawButton(term, 35, 4, 17, 3, "Deposit", colors.white, colors.green)
        if account.balance > 0 then
            buttons.withdraw = g.drawButton(term, 35, 8, 17, 3, "Withdraw", colors.white, colors.purple)
            buttons.transfer = g.drawButton(term, 35, 12, 17, 3, "Transfer", colors.white, colors.orange)
        else
            buttons.close = g.drawButton(term, 35, 16, 17, 3, "Close Account", colors.white, colors.red)
        end
        local event, button, x, y = os.pullEvent("mouse_click")
        if button == 1 then
            if y == 2 and x >= W-3 then
                return -- exit back to the accounts UI
            elseif g.isButtonPressed(x, y, buttons.deposit) then
                local success = showDepositUI(account)
                if success then return end -- If successful, go back to the accounts page.
            elseif buttons.withdraw and g.isButtonPressed(x, y, buttons.withdraw) then
                local success = showWithdrawUI(account)
                if success then return end
            elseif buttons.transfer and g.isButtonPressed(x, y, buttons.transfer) then
                -- Do Transfer
                return
            elseif buttons.close and g.isButtonPressed(x, y, buttons.close) then
                
            end
        end
    end
end

local function showAccountsUI()
    while true do
        drawFrame()
        g.drawXLine(term, 1, 19, 2, colors.gray)
        g.drawText(term, 2, 2, "Account", colors.white, colors.gray)
        g.drawXLine(term, 10, 35, 2, colors.lightGray)
        g.drawText(term, 11, 2, "Name", colors.white, colors.lightGray)
        g.drawXLine(term, 36, W, 2, colors.gray)
        g.drawText(term, 37, 2, "Balance", colors.white, colors.gray)
        g.drawText(term, W-6, 2, "Log Out", colors.white, colors.red)
        local accounts, errorMsg = bankClient.getAccounts()
        if accounts then
            for i, account in pairs(accounts) do
                local bg = colors.blue
                if i % 2 == 0 then bg = colors.lightBlue end
                local fg = colors.white
                local y = i + 2
                g.drawXLine(term, 1, W, y, bg)
                g.drawText(term, 2, y, shortId(account), fg, bg)
                g.drawText(term, 11, y, account.name, fg, bg)
                g.drawText(term, 37, y, tostring(account.balance), fg, bg)
            end
        else
            g.drawTextCenter(term, W/2, 4, "Error: " .. errorMsg, colors.red, colors.white)
        end
        local event, button, x, y = os.pullEvent("mouse_click")
        if button == 1 then
            if accounts and y > 2 and (y - 2) <= #accounts then
                showAccountUI(accounts[y-2])
            elseif y == 2 and x >= W-6 then
                bankClient.logOut()
                return
            end
        end
    end
end

local function logoutAfterInactivity()
    local function now() return os.epoch("utc") end
    local DELAY = 30000
    local lastActivity = now()
    while now() < lastActivity + DELAY do
        parallel.waitForAny(
            function () os.sleep(1) end,
            function ()
                local event = os.pullEvent()
                if event == "mouse_click" or event == "key" or event == "key_up" or event == "char" then
                    lastActivity = now()
                end
            end
        )
    end
    bankClient.logOut()
    drawFrame()
    g.drawText(term, 2, 3, "Logged out due to inactivity.", colors.gray, colors.white)
    os.sleep(2)
end

while true do
    local credentials = showLoginUI()
    local loginSuccess = checkCredentialsUI(credentials)
    if loginSuccess then
        parallel.waitForAny(showAccountsUI, logoutAfterInactivity)
    end
end