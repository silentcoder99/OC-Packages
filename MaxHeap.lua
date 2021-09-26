MaxHeap = {}
MaxHeap.__index = MaxHeap

function MaxHeap:new()
  local obj = {
    nodes = {}
  }

  setmetatable(obj, self)
  return obj
end

MaxHeap.__len = function(self)
  return #self.nodes
end

function MaxHeap:swim(index)
  if index == 1 then
    return
  end

  local parentIndex = math.floor(index / 2)
  local parent = self.nodes[parentIndex]
  local child = self.nodes[index]

  if parent.priority < child.priority then
    self.nodes[parentIndex] = child
    self.nodes[index] = parent

    self:swim(parentIndex)
  end
end

function MaxHeap:sink(index)
  if index * 2 > #self.nodes then
    return
  end

  local left = self.nodes[index * 2]
  local right = self.nodes[index * 2 + 1]
  local parent = self.nodes[index]
  local maxChild = {}
  local maxIndex = nil

  if right == nil then
    maxChild = left
    maxIndex = index * 2
  elseif left.priority >= right.priority then
    maxChild = left
    maxIndex = index * 2
  else
    maxChild = right
    maxIndex = index * 2 + 1
  end

  if maxChild.priority > parent.priority then
    self.nodes[index] = maxChild
    self.nodes[maxIndex] = parent
    self:sink(maxIndex)
  end
end

function MaxHeap:push(value, priority)
  local node = {
    value = value,
    priority = priority
  }

  table.insert(self.nodes, node)
  self:swim(#self.nodes)
end

function MaxHeap:pop()
  if #self.nodes == 0 then
    return nil
  end

  local top = self.nodes[1]

  --Set last node as root
  self.nodes[1] = self.nodes[#self.nodes]
  table.remove(self.nodes)
  self:sink(1)

  return top.value
end

function MaxHeap:peek()
  local top = self.nodes[1]
  return top.value
end

return MaxHeap
