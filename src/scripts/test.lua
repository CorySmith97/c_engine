local function even_fibo()
  -- create Fibonacci sequence
  local fib = {1, 2}  -- starting with 1, 2
  for i=3, 10 do
    fib[i] = fib[i-2] + fib[i-1]
  end
  -- calculate sum of even numbers
  local fib_sum = 0
  for _, v in ipairs(fib) do
    if v%2 == 0 then
      fib_sum = fib_sum + v
    end
  end
  return fib_sum
end

local fib = even_fibo()
print("This is the fibinacci number called from lua", fib)

print("Entity id", entity.getId())
