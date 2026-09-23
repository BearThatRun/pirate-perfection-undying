-- usage: luajit syntax.lua file1 file2 ...
local fails = 0
for i = 1, #arg do
  local f = assert(io.open(arg[i], 'rb')); local s = f:read('*a'); f:close()
  s = s:gsub('^\239\187\191', '')
  local ok, err = loadstring(s, '@' .. arg[i])
  if not ok then print('FAIL: ' .. err); fails = fails + 1 end
end
print(('checked=%d failed=%d'):format(#arg, fails))
