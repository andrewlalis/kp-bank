--[[
bank.lua is the central bank server code, which runs 24/7 on a single computer
that is globally available via wireless connectivity (ender modem). It keeps a
persistent record of all accounts, and all transactions for accounts.

This program essentially serves as a simplified REST API for ingame clients,
like pocket computers and ATMs, for managing funds.
]]--

local USERS_DIR = "users"
local USER_DATA_FILE = "data.json"
local ACCOUNTS_FILE = "accounts.json"

local HOST = "central-bank"

local RUNNING = true

local g = require("simple-graphics")
local W, H = term.getSize()
g.clear(term, colors.black)
g.drawTextCenter(term, W/2, 1, "BANK Server @ " .. HOST, colors.lime, colors.black)
g.drawXLine(term, 1, W, 2, colors.black, colors.gray, "-")
g.drawText(term, W-3, 1, "Quit", colors.white, colors.red)

local console = g.createConsole(W, H-2, colors.white, colors.black, "DOWN")

local function log(msg)
    g.appendAndDrawConsole(term, console, textutils.formatTime(os.time()) .. ": " .. msg, 1, 3)
end

-- Helper functions

local function readJSON(filename)
    local f = io.open(filename, "r")
    if not f then error("Cannot open file " .. filename .. " to read JSON data.") end
    local data = textutils.unserializeJSON(f:read("*a"))
    f:close()
    return data
end

local function writeJSON(filename, data)
    local f = io.open(filename, "w")
    if not f then error("Cannot open file " .. filename .. " to write JSON data.") end
    f:write(textutils.serializeJSON(data))
    f:close()
end

-- Basic account functions:

local function validateUsername(name)
    local i, j = string.find(name, "%a%a%a+")
    return (
        i == 1 and
        j == #name and
        j <= 12
    )
end

local function userDir(name)
    return fs.combine(USERS_DIR, name)
end

local function userDataFile(name)
    return fs.combine(USERS_DIR, name, USER_DATA_FILE)
end

local function userAccountsFile(name)
    return fs.combine(USERS_DIR, name, ACCOUNTS_FILE)
end

local function accountTransactionsFile(username, accountId)
    return fs.combine(USERS_DIR, username, "tx_" .. accountId .. ".txt")
end

local function userExists(name)
    return validateUsername(name) and fs.exists(userDir(name))
end

local function validatePassword(password)
    return #password >= 8
end

local function randomAccountId()
    local id = ""
    for i = 1, 16 do
        id = id .. tostring(math.random(0, 9))
        if i % 4 == 0 and i < 16 then
            id = id .. "-"
        end
    end
    return id
end

local function getUserData(name)
    return readJSON(userDataFile(name))
end

local function getAccounts(name)
    return readJSON(userAccountsFile(name))
end

local function saveAccounts(name, accounts)
    writeJSON(userAccountsFile(name), accounts)
end

local function createAccount(username, accountName)
    local accounts = getAccounts(username)
    for i, account in pairs(accounts) do
        if account.name == accountName then
            return false, "Duplicate account name"
        end
    end
    local newAccount = {
        id = randomAccountId(),
        name = accountName,
        balance = 0,
        createdAt = os.epoch("utc")
    }
    table.insert(accounts, newAccount)
    saveAccounts(username, accounts)
    log("Created account " .. newAccount.id .. " for user " .. username)
    return true, newAccount.id
end

local function deleteAccount(username, accountId)
    local accounts = getAccounts(username)
    local targetIndex = nil
    for i, account in pairs(accounts) do
        if account.id == accountId then
            targetIndex = i
        end
    end
    if targetIndex then
        table.remove(accounts, targetIndex)
        saveAccounts(username, accounts)
        log("Deleted user " .. username .. " account " .. accountId)
        return true
    end
    return false
end

local function renameAccount(username, accountId, newName)
    local accounts = getAccounts(username)
    local targetAccount = nil
    for i, account in pairs(accounts) do
        if account.id == accountId then
            targetAccount = account
        elseif account.name == newName then
            return false, "Duplicate account name"
        end
    end
    if not targetAccount then return false, "Account not found" end
    targetAccount.name = newName
    saveAccounts(accounts)
    log("Renamed user " .. username .. " account " .. accountId .. " to " .. newName)
    return true
end

local function createUser(name, password)
    if not validateUsername(name) then return false, "Invalid username" end
    if not validatePassword(password) then return false, "Invalid password" end
    if userExists(name) then return false, "Username taken" end
    local userData = {
        password = password,
        createdAt = os.epoch("utc")
    }
    fs.makeDir(userDir(name))
    writeJSON(userDataFile(name), userData) -- Flush user data file.
    saveAccounts(userAccountsFile(name), {}) -- Flush initial accounts file.
    createAccount(name, "Checking")
    createAccount(name, "Savings")
    log("Created new user: " .. name)
    return true
end

local function deleteUser(name)
    if not userExists(name) then return false end
    fs.delete(userDir(name))
    log("Deleted user \"" .. name .. "\".")
    return true
end

local function renameUser(oldName, newName)
    if not validateUsername(newName) then return false, "Invalid new username" end
    if not userExists(oldName) then return false, "User doesn't exist" end
    if userExists(newName) then return false, "New username is taken" end
    fs.move(userDir(oldName), userDir(newName))
    log("Renamed user \"" .. oldName .. "\" to \"" .. newName .. "\".")
    return true
end

-- EVENT HANDLING
-----------------

-- Helper function to wrap another function in an authentication check.
local function authProtect(func)
    return function (msg)
        if (
            not msg.auth or
            not msg.auth.username or 
            not msg.auth.password or
            not userExists(msg.auth.username) or
            getUserData(msg.auth.username).password ~= msg.auth.password
        ) then
            return {success = false, error = "Invalid credentials"}
        end
        return func(msg)
    end
end

local function handleCreateUser(msg)
    if not msg.data or not msg.data.username or not msg.data.password then
        return {success = false, error = "Invalid request. Requires data.username and data.password."}
    end
    local success, errorMsg = createuser(msg.data.username, msg.data.password)
    if not success then
        return {success = false, error = errorMsg}
    end
    return {success = true}
end

local function handleDeleteUser(msg)
    deleteUser(msg.auth.username)
    return {success = true}
end

local function handleRenameUser(msg)
    if not msg.data or not msg.data.newUsername then
        return {success = false, error = "Invalid request. Requires data.newUsername."}
    end
    local success, errorMsg = renameUser(msg.auth.username, msg.data.newUsername)
    if not success then
        return {success = false, error = errorMsg}
    end
    return {success = true}
end

local function handleGetUserAccounts(msg)
    return {success = true, data = getAccounts(msg.auth.username)}
end

local function handleDeleteUserAccount(msg)
    if not msg.data or not msg.data.accountId then
        return {success = false, error = "Invalid request. Requires data.accountId."}
    end
    deleteAccount(msg.auth.username, msg.data.accountId)
    return {success = true}
end

local function handleRenameUserAccount(msg)
    if not msg.data or not msg.data.accountId or not msg.data.newName then
        return {success = false, error = "Invalid request. Requires data.accountId and data.newName."}
    end
    local success, errorMsg = renameAccount(msg.auth.username, msg.data.accountid, msg.data.newName)
    return {success = success, error = errorMsg}
end

local function BANK_REQUESTS = {
    ["CREATE_USER"] = handleCreateUser,
    ["DELETE_USER"] = authProtect(handleDeleteUser)
    ["RENAME_USER"] = authProtect(handleRenameUser)
    ["GET_ACCOUNTS"] = authProtect(handleGetUserAccounts)
    ["DELETE_ACCOUNT"] = authProtect(handleDeleteUserAccount)
    ["RENAME_ACCOUNT"] = authProtect(handleRenameUserAccount)
}

local function handleBankMessage(remoteId, msg)
    if msg == nil or msg.command == nil or type(msg.command) ~= "string" then
        return {success = false, error = "Invalid BANK request. Message is nil or missing \"command\" string property."}
    end
    if BANK_REQUESTS[msg.command] then
        return BANK_REQUESTS[msg.command](msg)
    end
    return {success = false, error = "Unknown command: \"" .. msg.command .. "\""}
end

local function handleNetworkEvents()
    log("Initializing Rednet hosting...")
    rednet.open("top")
    rednet.host("BANK", HOST)
    log("Opened Rednet and hosted BANK at host \"" .. HOST .. "\".")
    log("Now receiving requests.")
    while RUNNING do
        local remoteId, msg = rednet.receive("BANK", 3)
        if remoteId ~= nil then
            log("Received rednet message from computer ID " .. remoteId)
            local success, response = pcall(handleBankMessage, remoteId, msg)
            if not success then
                response = {success = false, error = "An error occurred: " .. response}
            end
            rednet.send(remoteId, response, "BANK")
        end
    end
    rednet.unhost("BANK")
    rednet.close()
end

local function handleGuiEvents()
    while RUNNING do
        local event, button, x, y = os.pullEvent("mouse_click")
        if button == 1 and y == 1 and x > W - 4 then
            log("Quitting...")
            RUNNING = false
        end
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function handleEvents()
    parallel.waitForAll(
        handleNetworkEvents,
        handleGuiEvents
    )
end

local args = {...}

if args[1] == "-i" then
    print("Reinstalling from GitHub.")
    fs.delete("bank.lua")
    shell.execute("wget", "https://raw.githubusercontent.com/andrewlalis/kp-bank/main/bank.lua")
    shell.execute("bank.lua")
end

handleEvents()
