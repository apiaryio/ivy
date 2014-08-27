crypto = require 'crypto'

config = require './config'
log    = require('./logger')

# I'd use ECDH-ECDSA-AES128-GCM-SHA256, but node.js support should be less, well, cryptic
# But like, who is not using ECs those days?
# For our uses, however, AES in cipher block chaining mode should be enough
SELECTED_ALGORITHM   = 'aes-256-cbc'

# Heroku's environment size restriction prevents us from using long passwords.
# Thus, derive a hash from it and use it as password

ENCRYPTION_DELIMITER = '$'

getEncrypted = (message, password, cb) ->
  encryptedMessage = ''

  try
    cipher = crypto.createCipher SELECTED_ALGORITHM, crypto.createHash('sha512').update(password).digest('binary')
    encryptedMessage += cipher.update message, 'utf-8', 'base64'
    encryptedMessage += cipher.final 'base64'
    # Might be thrown on bad input or when openssl is not compiled with SELECTED_ALGORITHM
  catch err
    return cb err

  cb null, (ENCRYPTION_DELIMITER + SELECTED_ALGORITHM + ENCRYPTION_DELIMITER + encryptedMessage)


getDecrypted = (encryptedMessage, password, cb) ->
  try
    [_, cipher, rawEncToken] = encryptedMessage.split '$', 3

    if cipher is not SELECTED_ALGORITHM
      log.warn "Using message encrypted using #{cipher} instead of current #{SELECTED_ALGORITHM}"

    decText = ''

    decipher = crypto.createDecipher cipher, crypto.createHash('sha512').update(password).digest('binary')
    decText += decipher.update rawEncToken, 'base64'

    decText += decipher.final 'utf-8'
    return cb null, decText
  # Might be thrown on bad input or when openssl is not compiled with SELECTED_ALGORITHM
  catch err
    return cb err

isEncrypted = (message) ->
  '$' is message.slice 0, 1

getMessage = (message, cb) ->
  if isEncrypted message
    getDecrypted message, cb
  else
    cb null, message


module.exports = {
  getEncrypted
  getDecrypted
  getMessage
  isEncrypted
  SELECTED_ALGORITHM
}
