local CurrentLevel = require "necro.game.level.CurrentLevel"
local TablePool = require("Topaz.libs.TablePool")
local Utils = require("Topaz.Utils")

local Data = TablePool.fetch(0, 2)

Data.NodeCache = TablePool.fetch(0, 5)

function Data.NodeCache:new()
	local obj = TablePool.fetch(0, 2)
	obj.hashMap = TablePool.fetch(0, 40)
	obj.levelNumber = 0
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function Data.NodeCache:hash(x, y)
	return x .. "_" .. y
end

function Data.NodeCache:checkLevel()
	local level = CurrentLevel.getNumber()
	if level ~= self.levelNumber then
		Utils.tableClear(self.hashMap)
		self.levelNumber = level
	end
end

function Data.NodeCache:insertNode(x, y, node)
	self:checkLevel()
	local key = self:hash(x, y)
	self.hashMap[key] = node
end

function Data.NodeCache:getNode(x, y)
	self:checkLevel()
	local key = self:hash(x, y)
	return self.hashMap[key]
end

Data.MinHeap = TablePool.fetch(0, 3)

function Data.MinHeap:new()
	local heap = TablePool.fetch(0, 1)
	heap.data = TablePool.fetch(15, 0)
	setmetatable(heap, self)
	self.__index = self
	return heap
end

function Data.MinHeap:push(node, cost)
	local heap = self.data
	local heapNode = TablePool.fetch(0, 2)
	heapNode.node = node
	heapNode.cost = cost
	table.insert(heap, heapNode)
	local currentIndex = #heap
	local parentIndex = math.floor(currentIndex / 2)

	while parentIndex > 0 and heap[currentIndex].cost < heap[parentIndex].cost do
		heap[currentIndex], heap[parentIndex] = heap[parentIndex], heap[currentIndex]
		currentIndex = parentIndex
		parentIndex = math.floor(currentIndex / 2)
	end
end

function Data.MinHeap:pop()
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

return Data