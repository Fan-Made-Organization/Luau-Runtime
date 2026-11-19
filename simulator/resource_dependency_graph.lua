--[[
    FMO Resource Dependency Graph
    Read-only graph analysis over ResourceManager dependency metadata.
    It never releases resources or changes dependency edges.
]]
local ResourceManager = require("./resource_manager")

local Graph = {
    Enabled = true,
    MaximumSnapshots = 25,
    _history = {},
    _nextSnapshot = 0,
    _statistics = { Builds = 0, CyclesDetected = 0, MissingEdges = 0 },
}

local function sortedKeys(set)
    local result = {}
    for key in pairs(set) do result[#result + 1] = key end
    table.sort(result)
    return result
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for k, v in pairs(value) do out[copy(k, seen)] = copy(v, seen) end
    return out
end

local function build()
    local nodes, edges, missing = {}, {}, {}
    for _, id in ipairs(ResourceManager:List()) do
        nodes[id] = true
        edges[id] = {}
    end
    for _, id in ipairs(ResourceManager:List()) do
        for _, dependency in ipairs(ResourceManager:GetDependencies(id)) do
            if nodes[dependency] then
                edges[id][dependency] = true
            else
                missing[#missing + 1] = { Resource = id, Dependency = dependency }
            end
        end
    end
    table.sort(missing, function(a,b)
        if a.Resource ~= b.Resource then return a.Resource < b.Resource end
        return a.Dependency < b.Dependency
    end)
    return nodes, edges, missing
end

local function analyzeCycles(nodes, edges)
    local state, stack, position, cycles = {}, {}, {}, {}
    local function visit(id)
        state[id] = 1
        stack[#stack + 1] = id
        position[id] = #stack
        for _, dependency in ipairs(sortedKeys(edges[id] or {})) do
            if state[dependency] == nil then
                visit(dependency)
            elseif state[dependency] == 1 then
                local cycle = {}
                for i = position[dependency], #stack do
                    cycle[#cycle + 1] = stack[i]
                end
                cycle[#cycle + 1] = dependency
                cycles[#cycles + 1] = cycle
            end
        end
        position[id] = nil
        stack[#stack] = nil
        state[id] = 2
    end
    for _, id in ipairs(sortedKeys(nodes)) do
        if state[id] == nil then visit(id) end
    end
    return cycles
end

local function topological(nodes, edges)
    local indegree, dependents = {}, {}
    for id in pairs(nodes) do indegree[id] = 0; dependents[id] = {} end
    for id, dependencies in pairs(edges) do
        for dependency in pairs(dependencies) do
            indegree[id] += 1
            dependents[dependency][#dependents[dependency] + 1] = id
        end
    end
    for _, list in pairs(dependents) do table.sort(list) end
    local ready = {}
    for id, degree in pairs(indegree) do if degree == 0 then ready[#ready + 1] = id end end
    table.sort(ready)
    local order = {}
    while #ready > 0 do
        local id = table.remove(ready, 1)
        order[#order + 1] = id
        for _, dependent in ipairs(dependents[id]) do
            indegree[dependent] -= 1
            if indegree[dependent] == 0 then
                ready[#ready + 1] = dependent
                table.sort(ready)
            end
        end
    end
    return order, #order == (function() local n=0; for _ in pairs(nodes) do n+=1 end; return n end)()
end

function Graph:Build()
    if not self.Enabled then return false, "Dependency graph is disabled" end
    local nodes, edges, missing = build()
    local cycles = analyzeCycles(nodes, edges)
    local order, acyclic = topological(nodes, edges)
    local incoming, outgoing = {}, {}
    for id in pairs(nodes) do incoming[id] = 0; outgoing[id] = 0 end
    for id, dependencies in pairs(edges) do
        outgoing[id] = 0
        for dependency in pairs(dependencies) do
            outgoing[id] += 1
            incoming[dependency] += 1
        end
    end
    local nodeList, edgeList = sortedKeys(nodes), {}
    for _, id in ipairs(sortedKeys(nodes)) do
        for _, dependency in ipairs(sortedKeys(edges[id])) do
            edgeList[#edgeList + 1] = { Resource = id, DependsOn = dependency }
        end
    end
    self._nextSnapshot += 1
    local snapshot = {
        Id = self._nextSnapshot, CapturedAt = os.clock(),
        Nodes = nodeList, Edges = edgeList, MissingEdges = missing,
        Cycles = cycles, TopologicalOrder = order, IsAcyclic = acyclic,
        Metrics = { NodeCount = #nodeList, EdgeCount = #edgeList,
            MissingEdgeCount = #missing, CycleCount = #cycles,
            RootCount = 0, LeafCount = 0 },
        Degrees = { Incoming = incoming, Outgoing = outgoing },
    }
    for _, id in ipairs(nodeList) do
        if outgoing[id] == 0 then snapshot.Metrics.RootCount += 1 end
        if incoming[id] == 0 then snapshot.Metrics.LeafCount += 1 end
    end
    self._history[#self._history + 1] = snapshot
    while #self._history > self.MaximumSnapshots do table.remove(self._history, 1) end
    self._statistics.Builds += 1
    self._statistics.CyclesDetected += #cycles
    self._statistics.MissingEdges += #missing
    return true, copy(snapshot)
end

function Graph:GetImpact(id)
    local nodes, edges = build()
    if not nodes[id] then return nil, "Resource not found" end
    local affected, queue, cursor = {}, { id }, 1
    while cursor <= #queue do
        local current = queue[cursor]; cursor += 1
        for _, dependent in ipairs(sortedKeys(nodes)) do
            if edges[dependent] and edges[dependent][current] and not affected[dependent] then
                affected[dependent] = true
                queue[#queue + 1] = dependent
            end
        end
    end
    return sortedKeys(affected)
end

function Graph:GetDependencyClosure(id)
    local nodes, edges = build()
    if not nodes[id] then return nil, "Resource not found" end
    local found, queue, cursor = {}, { id }, 1
    while cursor <= #queue do
        local current = queue[cursor]; cursor += 1
        for _, dependency in ipairs(sortedKeys(edges[current] or {})) do
            if not found[dependency] then
                found[dependency] = true
                queue[#queue + 1] = dependency
            end
        end
    end
    return sortedKeys(found)
end

function Graph:GetLatest()
    local item = self._history[#self._history]
    return item and copy(item) or nil
end

function Graph:GetSnapshot(id)
    for _, item in ipairs(self._history) do
        if item.Id == id then return copy(item) end
    end
    return nil
end

function Graph:SetMaximumSnapshots(value)
    if type(value) ~= "number" or value < 1 or value % 1 ~= 0 then
        error("Maximum snapshots must be a positive integer", 2)
    end
    self.MaximumSnapshots = value
    while #self._history > value do table.remove(self._history, 1) end
    return true
end

function Graph:SetEnabled(value)
    self.Enabled = value == true
    return self.Enabled
end

function Graph:GetStatistics()
    return { Enabled = self.Enabled, Snapshots = #self._history,
        MaximumSnapshots = self.MaximumSnapshots, Builds = self._statistics.Builds,
        CyclesDetected = self._statistics.CyclesDetected,
        MissingEdges = self._statistics.MissingEdges }
end

function Graph:Reset()
    self._history = {}; self._nextSnapshot = 0
    self.Enabled = true; self.MaximumSnapshots = 25
    self._statistics = { Builds = 0, CyclesDetected = 0, MissingEdges = 0 }
    return true
end

return Graph
