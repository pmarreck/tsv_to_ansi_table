local oracle = dofile("tests/benchmark/oracle.lua")
local _, expected = oracle.fixture(2, 15)
assert(oracle.verify("Name  Value\nrow-000001  16.01\nrow-000002  17.02\n", expected))
for _, bad in ipairs({"", "Name Value\n", "Name Value\nrow-000001 16.01\n", "Name Value\nrow-000002 17.02\nrow-000001 16.01\n", "Name Value\nrow-000001 16.0\nrow-000002 17.02\n", "Name Value\nrow-000001 16.01\nrow-000002 17.02\nextra 1\n"}) do
	assert(not oracle.verify(bad, expected), "oracle accepted skipped, reordered, rounded, or extra work")
end
print("PASS benchmark oracle rejects invalid work")
