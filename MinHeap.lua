MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap:new()
    local obj = {
        nodes = {}
    }
    
    setmetatable(obj, self)
    return obj
end

function MinHeap:swim(index)
    if index == 1 then
        return
    end
    
    local parentIndex = math.floor(index / 2)
    local parent = self.nodes[parentIndex]
    local child = self.nodes[index]
    
    if parent.priority > child.priority then
        self.nodes[parentIndex] = child
        self.nodes[index] = parent
        
        self:swim(parentIndex)
    end
end

function MinHeap:sink(index)
    if index * 2 > #self.nodes then
        return
    end
    
    local left = self.nodes[index * 2]
    local right = self.nodes[index * 2 + 1]
    local parent = self.nodes[index]
    local minChild = {}
    local minIndex = nil
    
    if right == nil then
        minChild = left
        minIndex = index * 2
    elseif left.priority <= right.priority then
        minChild = left
        minIndex = index * 2
    else
        minChild = right
        minIndex = index * 2 + 1
    end
    
    if minChild.priority < parent.priority then
        self.nodes[index] = minChild
        self.nodes[minIndex] = parent
        self:sink(minIndex)
    end
end

function MinHeap:push(value, priority)
    local node = {
        value = value,
        priority = priority
    }
    
    table.insert(self.nodes, node)
    self:swim(#self.nodes)
end

function MinHeap:pop()
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

function MinHeap:peek()
    local top = self.nodes[1]
    return top.value
end
    
return MinHeap
