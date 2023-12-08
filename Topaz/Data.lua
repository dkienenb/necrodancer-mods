local CurrentLevel = require "necro.game.level.CurrentLevel"
local clear = require("table.clear")
local NodeCache = {}

function NodeCache:new()
	local obj = {
		hashMap = {},
		levelNumber = 0
	}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function NodeCache:hash(x, y)
	return x .. "_" .. y
end

function NodeCache:checkLevel()
	local level = CurrentLevel.getNumber()
	if level ~= self.levelNumber then
		clear(self.hashMap)
		self.levelNumber = level
	end
end

function NodeCache:insertNode(x, y, node)
	self:checkLevel()
	local key = self:hash(x, y)
	self.hashMap[key] = node
end

function NodeCache:getNode(x, y)
	self:checkLevel()
	local key = self:hash(x, y)
	return self.hashMap[key]
end

local MinHeap = {}

function MinHeap:new()
	local heap = {data = {}}
	setmetatable(heap, self)
	self.__index = self
	return heap
end

function MinHeap:push(node, cost)
	local heap = self.data
	table.insert(heap, {node = node, cost = cost})
	local currentIndex = #heap
	local parentIndex = math.floor(currentIndex / 2)

	while parentIndex > 0 and heap[currentIndex].cost < heap[parentIndex].cost do
		heap[currentIndex], heap[parentIndex] = heap[parentIndex], heap[currentIndex]
		currentIndex = parentIndex
		parentIndex = math.floor(currentIndex / 2)
	end
end

function MinHeap:pop()
	local heap = self.data
	if #heap == 0 then
		return nil
	end

	local minNode = heap[1]
	local lastNode = table.remove(heap)
	if #heap > 0 then
		heap[1] = lastNode
		local currentIndex = 1
		local leftChildIndex = 2 * currentIndex
		local rightChildIndex = 2 * currentIndex + 1

		while true do
			local smallestIndex = currentIndex
			if leftChildIndex <= #heap and heap[leftChildIndex].cost < heap[smallestIndex].cost then
				smallestIndex = leftChildIndex
			end
			if rightChildIndex <= #heap and heap[rightChildIndex].cost < heap[smallestIndex].cost then
				smallestIndex = rightChildIndex
			end
			if smallestIndex == currentIndex then
				break
			else
				heap[currentIndex], heap[smallestIndex] = heap[smallestIndex], heap[currentIndex]
				currentIndex = smallestIndex
				leftChildIndex = 2 * currentIndex
				rightChildIndex = 2 * currentIndex + 1
			end
		end
	end

	return minNode.node
end

return {
	NodeCache = NodeCache,
	MinHeap = MinHeap
}