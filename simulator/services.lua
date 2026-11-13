local Services = {}

local registeredServices = {}

function Services.Register(name, service)
    registeredServices[name] = service
end

function Services.GetService(name)
    local service = registeredServices[name]

    if not service then
        error("Service '" .. tostring(name) .. "' was not found")
    end

    return service
end

function Services.Exists(name)
    return registeredServices[name] ~= nil
end

function Services.GetAll()
    return registeredServices
end

return Services
