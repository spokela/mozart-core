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
    @channels = []

  isOper: ->
    return @modes.indexOf 'o'

  changeModes: (modes) ->
    if modes.indexOf(' ') != -1
      args = modes.split ' '
    else
      args = [modes]

    operator = ""
    argsIdx = 1
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

      if operator == '+'
        @modes += curr
        if curr == 'o' && @server != undefined && @server.opers != undefined
          @server.opers++
      else
        @modes = @modes.replace curr, ''
        if curr == 'o' && @server != undefined && @server.opers != undefined
          @server.opers--
      i++

class Channel
  constructor: (@name, @timestamp = 0, @creator = null, @modes = "", @topic = null) ->
    @id       = uuid.v4()
    @users    = []
    @bans     = []
    @limit    = 0
    @key      = null

  changeModes: (modes) ->
    if modes.indexOf(' ') != -1
      args = modes.split(' ')
    else
      args = [modes]

    operator = ""
    argsIdx = 1
    i = 0
    while i <= args[0].length
      curr = args[0].charAt(i)
      if curr == '+' || curr == '-'
        operator = curr
      else if curr == 'k' && operator == '+'
        @key = args[argsIdx]
        argsIdx++
      else if curr == 'k' && operator == '-'
        @key = null
        argsIdx++
      else if curr == 'l' && operator == '+'
        @limit = args[argsIdx]
        argsIdx++
      else if curr == 'l' && operator == '-'
        @limit = null

      if operator == '+'
        @modes += curr
      else
        @modes = @modes.replace curr, ''
      i++

  addUser: (user, modes, timestamp) ->
    @users[user.id] = new ChannelUser(user, modes, timestamp)
    user.channels[@id] = @

  removeUser: (user) ->
    delete @users[user.id]
    delete user.channels[@id]

  isEmpty: ->
    if Object.keys(@users).length > 0
      return false
    else
      return true

  addBan: (mask, setter, timestamp) ->
    if !timestamp
      timestamp = @timestamp
    @bans.push new ChannelBan(mask, setter, timestamp)

class ChannelUser
  constructor: (@user, @modes = "", @joinTs = 0) ->
    @id       = uuid.v4()

class ChannelBan
  constructor: (@mask, @setter, @timestamp = 0) ->
    @id       = uuid.v4()

module.exports = {
  Server,
  User,
  Channel,
  ChannelUser,
  ChannelBan
}