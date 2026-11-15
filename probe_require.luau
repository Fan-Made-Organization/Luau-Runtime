local result = require("./probe_module")

print("TYPE:", type(result))
print("NAME:", type(result) == "table" and result.Name or result)
