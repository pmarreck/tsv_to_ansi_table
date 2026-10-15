local M = {}
function M.fixture(n, seed)
	local lines, expected = {"Name\tValue\n"}, {{"Name", "Value"}}
	for i = 1, n do
		local name = string.format("row-%06d", i)
		local value = string.format("%d.%02d", i + seed, i % 100)
		lines[#lines + 1] = name .. "\t" .. value .. "\n"
		expected[#expected + 1] = {name, value}
	end
	return table.concat(lines), expected
end
function M.verify(output, expected)
	if output:sub(-1) ~= "\n" then return false end
	local index = 0
	for line in output:gmatch("([^\n]*)\n") do
		index = index + 1
		local first, second = line:match("^%s*(%S+)%s+(%S+)%s*$")
		local row = expected[index]
		if not row or first ~= row[1] or second ~= row[2] then return false end
	end
	return index == #expected
end
return M
