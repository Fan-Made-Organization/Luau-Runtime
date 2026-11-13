local Signal = {}

local SignalMethods = {}
local ConnectionMethods = {}

local SignalMetatable = {
    __index = SignalMethods
}

local ConnectionMetatable = {
    __index = ConnectionMethods
}

function Signal.new()
    local self = {
        _connections = {},
        _destroyed = false,
    }

    return setmetatable(self, SignalMetatable)
end

function SignalMethods:Connect(callback)
    if self._destroyed then
        error("Cannot connect to a destroyed signal")
    end

    if type(callback) ~= "function" then
        error("Connect expects a function")
    end

    local connection = {
        Connected = true,
        _callback = callback,
        _signal = self,
    }

    setmetatable(connection, ConnectionMetatable)

    table.insert(self._connections, connection)

    return connection
end

function SignalMethods:Once(callback)
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

    local arguments = table.pack(...)
    local connections = {}

    for _, connection in ipairs(self._connections) do
        table.insert(connections, connection)
    end

    for _, connection in ipairs(connections) do
        if connection.Connected then
            connection._callback(
                table.unpack(arguments, 1, arguments.n)
            )
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

function SignalMethods:Destroy()
    if self._destroyed then
        return
    end

    self:DisconnectAll()
    self._destroyed = true
end

function ConnectionMethods:Disconnect()
    if not self.Connected then
        return
    end

    self.Connected = false

    local signal = self._signal

    if signal then
        for i, connection in ipairs(signal._connections) do
            if connection == self then
                table.remove(signal._connections, i)
                break
            end
        end
    end

    self._signal = nil
end

return Signal
