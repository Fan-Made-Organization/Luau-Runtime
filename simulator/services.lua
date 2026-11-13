local Services = {}

local registeredServices = {}

function Services.Register(name, service)
    if type(name) ~= "string" then
        error("Service name must be a string")
    end

    if type(service) ~= "table" then
        error("Service must be a table")
    end

    registeredServices[name] = service

    return service
end

function Services.GetService(name)
    local service = registeredServices[name]

    if not service then
        error("Service '" .. tostring(name) .. "' was not found")
    end

    return service
end

function Services.FindService(name)
    return registeredServices[name]
end

function Services.Exists(name)
    return registeredServices[name] ~= nil
end

function Services.Unregister(name)
    local service = registeredServices[name]

    registeredServices[name] = nil

    return service
end

function Services.GetAll()
    local services = {}

    for name, service in pairs(registeredServices) do
        services[name] = service
    end

    return services
end

function Services.GetServiceNames()
    local names = {}

    for name in pairs(registeredServices) do
        table.insert(names, name)
    end

    table.sort(names)

    return names
end

function Services.Clear()
    registeredServices = {}
end

function Services.Count()
    local count = 0

    for _ in pairs(registeredServices) do
        count = count + 1
    end

    return count
end

return Services
