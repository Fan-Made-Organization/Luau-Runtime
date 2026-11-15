local result = require("./simulator/runtime_manager")

print("RESULT TYPE:", type(result))
print("RESULT:", tostring(result))

if type(result) == "table" then
    for key, value in pairs(result) do
        print(key, type(value))
    end
end
