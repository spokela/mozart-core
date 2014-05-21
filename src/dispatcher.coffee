#
# This file is part of Mozart
# (c) Spokela 2014
#
cmds = require './commands'

STATUS = {
  OK:   'OK',
  ERROR: 'NOK'
}

ERRORS = {
  MISSING_PARAMETERS: "missing parameters",
  UNKNOWN: "unknown error"
}

class Dispatcher
  constructor: (@adapter) ->

  exec: (command, args...) ->
    console.log command
    if command == cmds.BOT_COMMANDS.CONNECT
      if args.length < 5
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        u = @adapter.createUser args[0], args[1], args[2], args[3], args[4]
        return @format u

    return 'OK'

  format: (data = null, isOk = true, error = null) ->
    if !isOk
      if error == null
        error = ERRORS.UNKNOWN
      response = {
        status: STATUS.ERROR,
        error: error
      }
    else
      response = {
        status: STATUS.OK,
        data: data
      }
    return JSON.stringify response

module.exports = Dispatcher