-- Utility functions that will be used across multiple addons

local MAJOR, MINOR = "DaiUtil-1.0", 1
local Lib = {}

local pairs, type, tostring, getmetatable = pairs, type, tostring, getmetatable

-- Walks a table to serialize any CColor and ApolloColor objects into tables
-- @param t The table to walk
Lib.SerializeColors = function(t)
  for k,v in pairs(t) do
    if type(v) == "table" then
      Lib.SerializeColors(v)
    else
      if type(v) == "userdata" and tostring(v):match("^CColor%(") then
        t[k] = { __CColor = true, r = v.r, b = v.b, g = v.g, a = v.a }
      elseif type(v) == "userdata" and type(getmetatable(v).IsSameColorAs) == "function" then
        t[k] = v:ToTable()
        t[k].__ApolloColor = true
      end
    end
  end
end

-- Walks a table to deserialize any CColor and ApolloColor objects serialized by SerializeColors
-- @param t The table to walk
Lib.DeserializeColors = function(t)
  for k,v in pairs(t) do
    if type(v) == "table" and v.__CColor then
      v = CColor.new(v.r, v.g, v.b, v.a)
    elseif type(v) == "table" and v.__ApolloColor then
      v = ApolloColor.new(v)
    elseif type(v) == "table" then
      Lib.DeserializeColors(v)
    end
  end
end

-- Copies a table
-- @param t The source table to copy
-- @return (table) the table copy
Lib.TableCopy = function(t)
  local t2 = {}
  if type(t) ~= "table" then
    return t
  end
  for k,v in pairs(t) do
    t2[k] = Lib.TableCopy(v)
  end
  return t2
end

-- Merges a two tables together
-- @param t1 First table to merge, the values from the second added
-- @param t2 Second table to merge into the first, unaltered
-- @return (table) The merged table (First table)
Lib.TableMerge = function(t1, t2)
  for k,v in pairs(t2) do
    if type(v) == "table" then
      if type(t1[k] or false) == "table" then
        Lib.TableMerge(t1[k] or {}, t2[k] or {})
      else
        t1[k] = v
      end
    else
      t1[k] = v
    end
  end
  return t1
end

Lib.StringSplit = function(str, sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  str:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

function Lib:OnLoad()
end

function Lib:OnDependencyError(strDep, strError)
  return false
end

Apollo.RegisterPackage(Lib, MAJOR, MINOR, {})