--[[
The bank-client is a library that applications can include to interact with
a central bank server. Note that it functions over the Rednet protocol, so you
should call `rednet.open("modem-name")` first.
]]--

local client = {}

client.state = {
    auth = nil,
    hostId = nil,
    securityKey = nil,
    timeout = 3
}

local function requestRaw(msg)
    if not client.state.hostId or not rednet.isOpen() then
        return {success = false, error = "Client not initialized"}
    end
    rednet.send(client.state.hostId, msg, "BANK")
    local remoteId, response = rednet.receive("BANK", client.state.timeout)
    if not remoteId then
        return {success = false, error = "Request timed out"}
    end
    return response
end

local function request(command, data)
    return requestRaw({command = command, data = data})
end

local function requestAuth(command, data, secure)
    secure = secure or false
    if not client.loggedIn() then
       return {success = false, error = "Client not logged in"} 
    end
    local authInfo = {
        username = client.state.auth.username,
        password = client.state.auth.password
    }
    if secure and not client.state.securityKey then
        return {success = false, error = "Missing security key for secure request."}
    end
    authInfo.key = client.state.securityKey
    return requestRaw({command = command, auth = authInfo, data = data})
end

-- Base functions

function client.init(modemName, host, securityKey)
    rednet.open(modemName)
    client.state.hostId = rednet.lookup("BANK", host)
    client.state.securityKey = securityKey or nil
    return client.state.hostId ~= nil
end

function client.logIn(username, password)
    client.state.auth = {username = username, password = password}
end

function client.logOut()
    client.state.auth = nil
end

function client.loggedIn()
    return client.state.auth ~= nil
end

-- BANK functions

function client.getStatus()
    local response = request("STATUS")
    return response.success, response.error
end

function client.createUser(username, password)
    local response = request("CREATE_USER", {username = username, password = password})
    return response.success, response.error
end

function client.deleteUser()
    local response = requestAuth("DELETE_USER")
    return response.success
end

function client.renameUser(newUsername)
    local response = requestAuth("RENAME_USER", {newUsername = newUsername})
    return response.success, response.error
end

function client.getAccounts()
    local response = requestAuth("GET_ACCOUNTS")
    if not response.success then
        return nil, response.error
    end
    return response.data
end

function client.createAccount(accountName)
    local response = requestAuth("CREATE_ACCOUNT", {name = accountName})
    if not response.success then
        return nil, response.error
    end
    return response.data
end

function client.deleteAccount(accountId)
    local response = requestAuth("DELETE_ACCOUNT", {accountId = accountId})
    return response.success
end

function client.renameAccount(accountId, newName)
    local response = requestAuth("RENAME_ACCOUNT", {accountId = accountId, newName = newName})
    return response.success, response.error
end

function client.recordTransaction(accountId, amount, description)
    local response = requestAuth("RECORD_TRANSACTION", {accountId = accountId, amount = amount, description = description}, true)
    if not response.success then
        return nil, response.error
    end
    return response.data
end

return client
