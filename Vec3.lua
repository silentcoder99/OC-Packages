Vec3 = {}
function Vec3:new(x, y, z)
  local obj = {
    x = x,
    y = y,
    z = z
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function Vec3:map(func)
  return Vec3:new(
  func(self.x),
  func(self.y),
  func(self.z)
  )
end

Vec3.__eq = function(op1, op2)
  return op1.x == op2.x and
  op1.y == op2.y and
  op1.z == op2.z
end


Vec3.__add = function(op1, op2)
  return Vec3:new(
  op1.x + op2.x,
  op1.y + op2.y,
  op1.z + op2.z
  )
end

Vec3.__sub = function(op1, op2)
  return Vec3:new(
  op1.x - op2.x,
  op1.y - op2.y,
  op1.z - op2.z
  )
end

Vec3.__div = function(op1, op2)
  return Vec3:new(
  op1.x / op2.x,
  op1.y / op2.y,
  op1.z / op2.z
  )
end

Vec3.__mul = function(op1, op2)
  return Vec3:new(
  op1.x * op2.x,
  op1.y * op2.y,
  op1.z * op2.z
  )
end

Vec3.__tostring = function(vec)
  return string.format("%f, %f, %f", vec.x, vec.y, vec.z)
end

function Vec3:add(other)
  return Vec3:new(
  self.x + other.x,
  self.y + other.y,
  self.z + other.z
  )
end

return Vec3
