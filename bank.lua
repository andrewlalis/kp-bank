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
local TRANSACTIONS_FILE = "transactions.json"

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

local function userExists(name)
    return validateUsername(name) and fs.exists(userDir(name))
end

local function validatePassword(password)
    return #password >= 8
end

local function randomAccountId()
    local id = ""
    for i = 1, 16 do
        id = id .. tostring(math.random(1, 9))
        if i % 4 == 0 and i < 16 then
            id = id .. "-"
        end
    end
    return id
end

local function getAccounts(name)
    local f = io.open(userAccountsFile(name), "r")
    local accounts = textutils.unserializeJSON(f:read("*a"))
    f:close()
    return accounts
end

local function saveAccounts(name, accounts)
    local f = io.open(userAccountsFile(name), "w")
    f:write(textutils.serializeJSON(accounts))
    f:close()
end

local function createUser(name, password)
    if not validateUsername(name) then return false, "Invalid username" end
    if not validatePassword(password) then return false, "Invalid password" end
    if userExists(name) then return false, "Username taken" end
    local userData = {
        password = password
    }
    fs.makeDir(userDir(name))
    local dataFile = io.open(userDataFile(name), "w")
    dataFile:write(textutils.serializeJSON(userData))
    dataFile:close()
    -- Add an initial account.
    local initialAccounts = {
        {
            id = randomAccountId(),
            name = "Checking",
            balance = 0
        },
        {
            id = randomAccountId(),
            name = "Savings",
            balance = 0
        }
    }
    saveAccounts(name, initialAccounts)
    return true
end

local function deleteUser(name)
    if not userExists(name) then return false end
    fs.delete(userDir(name))
    return true
end

local function renameUser(oldName, newName)
    if not userExists(oldName) then return false, "User doesn't exist" end
    if userExists(newName) then return false, "New username is taken" end
    fs.move(userDir(oldName), userDir(newName))
    return true
end

rednet.open("modem")
rednet.host("BANK", "central-bank")

while true do
    local remoteId, msg = rednet.receive("BANK")
    print("Got message from " .. remoteId .. ": " .. msg)
end
