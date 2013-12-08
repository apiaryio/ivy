# Block event loop, thus async & able to be behind queue
factorial = (num, cb) ->
  if num < 0  then return cb new Error "Factorial not defined for negative values"
  if num == 0 then return cb null, 1

  result = 1

  while num > 0
    result = num * result
    num   -= 1

  cb null, num

module.exports = {
  factorial
}
