-- Runs every tests/*.spec.luau file. Usage: lune run tests/run
local fs = require("@lune/fs")
local process = require("@lune/process")
local lib = require("./lib")

local files = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

local passed, failed = 0, 0
for _, file in files do
	lib.registered = {}
	local ok, err = pcall(require, "./" .. string.gsub(file, "%.luau$", ""))
	if not ok then
		print(`FAIL {file} (could not load): {err}`)
		failed += 1
		continue
	end
	for _, t in lib.registered do
		local good, msg = pcall(t.fn)
		if good then
			passed += 1
			print(`PASS {file}: {t.name}`)
		else
			failed += 1
			print(`FAIL {file}: {t.name}: {msg}`)
		end
	end
end

print(`\n{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
