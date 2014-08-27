crypto = require 'crypto'

config = require './config'
log    = require('./logger')

# I'd use ECDH-ECDSA-AES128-GCM-SHA256, but node.js support should be less, well, cryptic
# But like, who is not using ECs those days?
# For our uses, however, AES in cipher block chaining mode should be enough
SELECTED_ALGORITHM   = 'aes-256-cbc'

# Heroku's environment size restriction prevents us from using long passwords.
# Thus, derive a hash from it and use it as password
ENCRYPTION_PASSWORD  = crypto.createHash('sha512').update(process.env.MESSAGES_ENCRYPTION_KEY).digest('binary')

ENCRYPTION_DELIMITER = '$'

getEncrypted = (message, cb) ->
  # For backward compatibility, store algorithm alongside encrypted message
  # Inspired by django, use $algorithm$message format
  # $ at the beginning is added to easily find whether message was already encrypted
  if not ENCRYPTION_PASSWORD or (process.env.NODE_ENV is 'production' and process.env.MESSAGES_ENCRYPTION_KEY is 'xxx')
    return cb new Error 'No message encryption key!'

  encryptedMessage = ''

  try
    cipher = crypto.createCipher SELECTED_ALGORITHM, ENCRYPTION_PASSWORD
    encryptedMessage += cipher.update message, 'utf-8', 'base64'
    encryptedMessage += cipher.final 'base64'
    # Might be thrown on bad input or when openssl is not compiled with SELECTED_ALGORITHM
  catch err
    return cb err

  cb null, (ENCRYPTION_DELIMITER + SELECTED_ALGORITHM + ENCRYPTION_DELIMITER + encryptedMessage)


getDecrypted = (encryptedMessage, cb) ->
  try
    decrypted = getDecryptedSync encryptedMessage
  # Might be thrown on bad input or when openssl is not compiled with SELECTED_ALGORITHM
  catch err
    return cb err

  cb null, decrypted

# Use getDecrypted instead!!!
# This is only for legacy code. It might get removed without notice,
# as acync magic may occur in the future (i.e. C-based async encryption libraries)
getDecryptedSync = (encryptedMessage) ->
  [_, cipher, rawEncToken] = encryptedMessage.split '$', 3

  if cipher is not SELECTED_ALGORITHM
    log.warn "Using message encrypted using #{cipher} instead of current #{SELECTED_ALGORITHM}"

  decText = ''

  decipher = crypto.createDecipher cipher, ENCRYPTION_PASSWORD
  decText += decipher.update rawEncToken, 'base64'

  decText += decipher.final 'utf-8'

  return decText


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
  getDecryptedSync
  getMessage
  isEncrypted
  SELECTED_ALGORITHM
}
