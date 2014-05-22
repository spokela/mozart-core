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
        i++
        continue;
      # specific IRCu
      # @todo remove this code from here
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
    @topicTs  = 0

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
        i++
        continue
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
    @users[user.id] = new ChannelUser(@, user, modes, timestamp)
    user.channels[@id] = @users[user.id]

  removeUser: (user) ->
    delete @users[user.id]
    delete user.channels[@id]

  isUser: (user) ->
    if !@users[user.id]
      return false
    return true

  isEmpty: ->
    if Object.keys(@users).length > 0
      return false
    else
      return true

  addBan: (mask, setter, timestamp) ->
    if !timestamp
      timestamp = @timestamp
    ban = new ChannelBan(mask, setter, timestamp)
    @bans[mask] = ban
    return ban

  removeBan: (mask) ->
    if @bans[mask] == undefined
      return false;

    ban = @bans[mask]
    delete @bans[mask]
    return ban

class ChannelUser
  constructor: (@channel, @user, @modes = "", @joinTs = 0) ->
    @id       = uuid.v4()

  changeModes: (modes) ->
    operator = ""
    i = 0
    while i <= modes.length
      curr = modes.charAt(i)
      if curr == '+' || curr == '-'
        operator = curr
      else if operator == '+'
        @modes += curr
      else
        @modes = @modes.replace curr, ''
      i++

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