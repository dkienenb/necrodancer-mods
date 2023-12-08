local newTable = require "table.new"
local clearTable = require "table.clear"
local setmetatable = setmetatable

local _M = newTable(0, 2)
local max_pool_size = 400
local pool
pool = newTable(4, 1)
pool.c = 0
pool[0] = 0

function _M.fetch(numArray, numNonArray)
	local len = pool[0]
	if len > 0 then
		local obj = pool[len]
		pool[len] = nil
		pool[0] = len - 1
		return obj
	end
	return newTable(numArray, numNonArray)
end

function _M.release(table)
	if not table then
		error("no table provided", 2)
	end
	do
		local cnt = pool.c + 1
		if cnt >= 20000 then
			pool = newTable(4, 1)
			pool.c = 0
			pool[0] = 0
			return
		end
		pool.c = cnt
	end

	local len = pool[0] + 1
	if len > max_pool_size then
		return
	end
	setmetatable(table, nil)
	clearTable(table)
	pool[len] = table
	pool[0] = len
end


return _M