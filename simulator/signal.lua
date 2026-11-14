local Signal = {}

local SignalMethods = {}
local ConnectionMethods = {}

local SignalMetatable = {
    __index = SignalMethods
}

local ConnectionMetatable = {
    __index = ConnectionMethods
}

local function removeConnection(signal, connection)
    if not signal then
        return
    end

    for i = #signal._connections, 1, -1 do
        if signal._connections[i] == connection then
            table.remove(signal._connections, i)
            return
        end
    end
end

function Signal.new()
    return setmetatable({
        _connections = {},
        _destroyed = false,

        _statistics = {
            connectionsCreated = 0,
            callbacksExecuted = 0,
            callbacksFailed = 0,
            fires = 0,
        },
    }, SignalMetatable)
end

function SignalMethods:Connect(callback)
    if self._destroyed then
        error("Cannot connect to a destroyed signal")
    end

    if type(callback) ~= "function" then
        error("Connect expects a function")
    end

    local connection = setmetatable({
        Connected = true,
        _callback = callback,
        _signal = self,
    }, ConnectionMetatable)

    table.insert(self._connections, connection)

    self._statistics.connectionsCreated =
        self._statistics.connectionsCreated + 1

    return connection
end

function SignalMethods:Once(callback)
    if type(callback) ~= "function" then
        error("Once expects a function")
    end

    local connection

    connection = self:Connect(function(...)
        connection:Disconnect()
        callback(...)
    end)

    return connection
end

function SignalMethods:Fire(...)
    if self._destroyed then
        return
    end

    self._statistics.fires = self._statistics.fires + 1

    local arguments = table.pack(...)
    local connections = {}

    for i, connection in ipairs(self._connections) do
        connections[i] = connection
    end

    for _, connection in ipairs(connections) do
        if connection.Connected then

            local success, errorMessage = pcall(
                connection._callback,
                table.unpack(arguments, 1, arguments.n)
            )

            if success then
                self._statistics.callbacksExecuted =
                    self._statistics.callbacksExecuted + 1
            else
                self._statistics.callbacksFailed =
                    self._statistics.callbacksFailed + 1

                -- Keep dispatching other callbacks.
                -- The error is recorded in statistics.
                connection._lastError = tostring(errorMessage)
            end
        end
    end
end

function SignalMethods:DisconnectAll()
    for _, connection in ipairs(self._connections) do
        connection.Connected = false
        connection._signal = nil
    end

    self._connections = {}
end

function SignalMethods:Count()
    local count = 0

    for _, connection in ipairs(self._connections) do
        if connection.Connected then
            count = count + 1
        end
    end

    return count
end

function SignalMethods:GetStatistics()
    local result = {}

    for key, value in pairs(self._statistics) do
        result[key] = value
    end

    result.activeConnections = self:Count()

    return result
end

function SignalMethods:IsDestroyed()
    return self._destroyed
end

function SignalMethods:Destroy()
    if self._destroyed then
        return
    end

    self._destroyed = true

    self:DisconnectAll()
end

function ConnectionMethods:Disconnect()
    if not self.Connected then
        return
    end

    self.Connected = false

    local signal = self._signal

    self._signal = nil
    self._callback = nil

    removeConnection(signal, self)
end

function ConnectionMethods:IsConnected()
    return self.Connected
end

return Signal
