# Block event loop, thus async & able to be behind queue
factorial = (num, cb) ->
  try
    res = factorialSync num
    cb null, res
  catch err
    cb err


factorialSync = (num) ->
  if num < 0  then return new Error "Factorial not defined for negative values"
  if num == 0 then return 1

  result = 1

  while num > 0
    result = num * result
    num   -= 1

  return result


module.exports = {
  factorial
  factorialSync
}
