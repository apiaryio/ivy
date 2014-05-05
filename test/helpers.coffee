
factorialFinishedCounterObject = {
  value: 0
}

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

factorialFinished = (err) ->
  factorialFinishedCounterObject.value += 1

sendObjectFinishedCounterObject = {
  value: 0
}

sendObject = ({message}, cb) ->
  cb null

sendObjectFinished = (err) ->
  sendObjectFinishedCounterObject.value += 1

module.exports = {
  factorial
  factorialFinished
  factorialFinishedCounterObject
  sendObject
  sendObjectFinished
  sendObjectFinishedCounterObject
}
