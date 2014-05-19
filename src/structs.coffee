#
# This file is part of Mozart
# (c) Spokela 2014
#
uuid = require 'node-uuid'

class Server
  constructor: (@name, @hops, @timestamp, @linkTimestamp, @description, @bursted = false, @parent = null) ->
    @users    = 0
    @opers    = 0
    @id       = uuid.v4()

  isUplink: ->
    return @hops == 1 ? true : false

class User
  constructor: (@nickname, @ident, @hostname, @realname, @server, @connectionTs) ->
    @lastNickname = null
    @modes    = ""
    @account  = false
    @away     = false
    @id       = uuid.v4()

  isOper: ->
    return @modes.indexOf 'o'

  changeModes: (modes) ->
    if modes.indexOf(' ') != -1
      args = modes.split ' '
    else
      args = [modes]

    operator = ""
    argsIdx = 0
    i = 0
    while i <= args[0].length
      curr = args[0].charAt i
      if curr == '+' || curr == '-'
        operator = curr
      else if curr == 'r' && operator == '+'
        @account = args[argsIdx]
        argsIdx++
      else if curr == 'r' && operator == '-'
        @account = false
        argsIdx++
      else if operator == '+'
        @modes += curr
        if curr == 'o' && @server != undefined && @server.opers != undefined
          @server.opers++
      else
        @modes = @modes.replace curr, ''
        if curr == 'o' && @server != undefined && @server.opers != undefined
          @server.opers--
      i++

module.exports = {
  Server,
  User
}