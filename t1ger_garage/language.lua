-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------

local locale = lib and lib.locale and lib.locale() or function(key)
  return key
end

Lang = setmetatable({}, {
  __index = function(_, key)
    local value = locale(key)
    if value ~= key then
      return value
    end
    return key
  end
})
