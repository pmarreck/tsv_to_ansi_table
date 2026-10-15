-- Whole-process CLI measurements. Fixture preparation, output checking, and
-- descriptor setup are outside timing; fork/exec, I/O, and locale startup count.
local ffi = require("ffi")
local json = require("cjson")
local oracle = dofile("tests/benchmark/oracle.lua")
ffi.cdef[[
struct tsv_timespec { long tv_sec; long tv_nsec; };
struct tsv_timeval { long tv_sec; long tv_usec; };
struct tsv_rusage { struct tsv_timeval user; struct tsv_timeval system; long rest[14]; };
int clock_gettime(int, struct tsv_timespec *);
int mkstemp(char *); int close(int); int unlink(const char *);
long write(int, const void *, unsigned long); long read(int, void *, unsigned long);
long lseek(int, long, int); int ftruncate(int, long);
int fork(void); int dup2(int, int); int execv(const char *, char *const *);
void _exit(int); int wait4(int, int *, int, struct tsv_rusage *);
]]
assert(ffi.os == "Linux" or ffi.os == "OSX", "benchmark adapter requires POSIX wait4")
local function temporary()
	local template = (os.getenv("TMPDIR") or "/tmp") .. "/tsv-bm-XXXXXX"
	local path = ffi.new("char[?]", #template + 1, template)
	local fd = ffi.C.mkstemp(path)
	assert(fd >= 0, "mkstemp failed")
	assert(ffi.C.unlink(path) == 0, "unlink private scratch failed")
	return tonumber(fd)
end
local function write_all(fd, s)
	local offset = 0
	while offset < #s do
		local n = tonumber(ffi.C.write(fd, s:sub(offset + 1), #s - offset))
		assert(n > 0, "fixture write failed")
		offset = offset + n
	end
end
local function read_all(fd)
	assert(ffi.C.lseek(fd, 0, 0) == 0)
	local parts, buffer = {}, ffi.new("char[65536]")
	while true do
		local n = tonumber(ffi.C.read(fd, buffer, 65536))
		assert(n >= 0, "output read failed")
		if n == 0 then break end
		parts[#parts + 1] = ffi.string(buffer, n)
	end
	return table.concat(parts)
end
local function now()
	local t = ffi.new("struct tsv_timespec[1]")
	assert(ffi.C.clock_gettime(ffi.os == "OSX" and 6 or 1, t) == 0, "monotonic clock failed")
	return tonumber(t[0].tv_sec) * 1e9 + tonumber(t[0].tv_nsec)
end
local case, sizes, seed = assert(arg[1]), assert(arg[2]), assert(tonumber(arg[3]))
local implementation, mode = case:match("^(%a+)%-(%a+)%-%d+$")
assert(implementation == "roc" or implementation == "zig")
assert(mode == "auto" or mode == "fixed")
local directory = assert(os.getenv("TSV_BENCH_BIN"), "TSV_BENCH_BIN must identify the optimized product")
local executable = directory .. "/tsv-to-ansi-table-" .. implementation
local argv = {executable, "--plain", "--color", "never", "--terminal-width", "80"}
if mode == "fixed" then argv[#argv+1] = "--widths"; argv[#argv+1] = "20,12" end
local cargv = ffi.new("char *[?]", #argv + 1)
for i, value in ipairs(argv) do cargv[i-1] = ffi.cast("char *", value) end
local input, output, errors = temporary(), temporary(), temporary()
local rows = {}
for raw_size in sizes:gmatch("[^,]+") do
	local n = assert(tonumber(raw_size))
	local fixture, expected = oracle.fixture(n, seed)
	assert(ffi.C.ftruncate(input, 0) == 0 and ffi.C.lseek(input, 0, 0) == 0)
	write_all(input, fixture)
	local samples = {wall_ns = {}, cpu_ns = {}}
	for iteration = 1, 7 do
		collectgarbage("collect")
		assert(ffi.C.lseek(input, 0, 0) == 0)
		for _, fd in ipairs({output, errors}) do assert(ffi.C.ftruncate(fd, 0) == 0 and ffi.C.lseek(fd, 0, 0) == 0) end
		local usage, status = ffi.new("struct tsv_rusage[1]"), ffi.new("int[1]")
		local started = now()
		local pid = ffi.C.fork()
		assert(pid >= 0, "fork failed")
		if pid == 0 then
			if ffi.C.dup2(input, 0) < 0 or ffi.C.dup2(output, 1) < 0 or ffi.C.dup2(errors, 2) < 0 then ffi.C._exit(126) end
			ffi.C.close(input); ffi.C.close(output); ffi.C.close(errors)
			ffi.C.execv(executable, cargv)
			ffi.C._exit(127)
		end
		local waited
		repeat waited = ffi.C.wait4(pid, status, 0, usage) until waited >= 0 or ffi.errno() ~= 4
		assert(waited == pid, "wait4 failed")
		local wall = now() - started
		local cpu = (tonumber(usage[0].user.tv_sec) + tonumber(usage[0].system.tv_sec)) * 1e9 + (tonumber(usage[0].user.tv_usec) + tonumber(usage[0].system.tv_usec)) * 1e3
		assert(status[0] == 0, "CLI failed: " .. read_all(errors))
		assert(read_all(errors) == "", "stderr/debug output in optimized benchmark")
		assert(oracle.verify(read_all(output), expected), "incorrect, missing, or reordered output")
		assert(wall > 0 and cpu > 0, "clock resolution insufficient")
		if iteration > 2 then samples.wall_ns[#samples.wall_ns+1] = wall; samples.cpu_ns[#samples.cpu_ns+1] = cpu end
	end
	rows[#rows+1] = {size=n, samples=samples}
end
for _, fd in ipairs({input, output, errors}) do assert(ffi.C.close(fd) == 0) end
print(json.encode({schema="performance-measurement/v1", correct=true, build_mode="ReleaseFast", allocator_coverage="not measured", rows=rows, implementation=implementation, mode=mode, method="fork-exec CLI; monotonic wall and wait4 child CPU including subprocesses; two warmups; five fresh-process samples; RAM-backed regular-file I/O", product=directory}))
