#
# This file is part of Mozart
# (c) Spokela 2014
#
{EventEmitter} = require 'events'

IRC_EVENTS = {
  # Mozart-Specific Events
  UPLINK_CONNECTED:   "irc:uplink-connected",

  # Server Events
  PING:               "irc:ping",
  SERVER_ENDBURST:    "irc:server-endburst",
  SERVER_REGISTERED:  "irc:server-registered",
  SERVER_QUIT:        "irc:server-quit",

  # User Events
  USER_REGISTERED:    "irc:user-registered",
  USER_QUIT:          "irc:user-quit",
  USER_NICKCHANGE:    "irc:user-nickchange",
  USER_MODESCHANGE:   "irc:user-modeschange",
  USER_AWAY:          "irc:user-away"
}

class Adapter extends EventEmitter
  constructor: (@config) ->
    @_preParsedTxt = ""
    @servers  = []
    @users    = []

  init: (@socket) ->
    self = @
    @socket.on "data", (data) ->
      self.preParse new String(data)

    @socket.on "end", () ->
      console.log "socket end";

    @connect()

  preParse: (data) ->
    num = 0
    while num <= data.length
      if data.charAt(num) == "\n"
        @parse @_preParsedTxt
        @_preParsedTxt = ""
      else
        @_preParsedTxt += data.charAt(num);
      num++

  doubleDotStr: (splitted, index) ->
    next = []
    while index <= splitted.length
      next.push splitted[index];
      index++

    return next.join(' ').substr(1).trim()

  send: (line) ->

  serverSend: (msg) ->

  sendPong: (timestamp) ->

  parse: (line) ->

  handlePing: (timestamp) ->
    @emit IRC_EVENTS.PING, timestamp
    @sendPong timestamp

  serverAdd: (server) ->
    if server == false
      throw new Error 'invalid server'

    @servers[server.id] = server
    @emit IRC_EVENTS.SERVER_REGISTERED, server

  serverQuit: (server, sender, reason) ->
    if server == false
      throw new Error 'invalid server'

    @emit IRC_EVENTS.SERVER_QUIT, server, sender, reason

    for id, serv of @servers
      if serv.parent.id == server.id
        @deleteUsersFromServer(serv, reason)
        delete @servers[server.id]

    @deleteUsersFromServer(server, reason)
    delete @servers[server.id]

  userAdd: (user) ->
    if user == false || user.server == false
      throw new Error 'invalid user or server'

    user.server.users++
    @users[user.id] = user
    @emit IRC_EVENTS.USER_REGISTERED, user

  userQuit: (user, reason) ->
    if user == false
      throw new Error 'invalid user'

    user.server.users--
    if user.isOper
      user.server.opers--

    delete @users[user.id]
    @emit IRC_EVENTS.USER_QUIT, user, reason

  userAway: (user, reason) ->
    if user == false
      throw new Error 'invalid user'

    user.away = reason
    @emit IRC_EVENTS.USER_AWAY, user, reason

  nickChange: (user, newNick) ->
    if user == false
      throw new Error 'invalid user'

    user.lastNickname = user.nickname
    user.nickname = newNick
    @emit IRC_EVENTS.USER_NICKCHANGE, user

  endOfBurst: (server) ->
    if server == false
      throw new Error 'invalid server'

    server.bursted = true;
    @emit IRC_EVENTS.SERVER_ENDBURST, server
    if server.isUplink()
      @emit IRC_EVENTS.UPLINK_CONNECTED;

  umodesChange: (sender, user, modes) ->
    if user == false || sender == false
      throw new Error 'invalid sender or user'

    user.changeModes modes;
    @emit IRC_EVENTS.USER_MODESCHANGE, user, modes, sender

  disconnect: ->

  findUserByNickname: (nickname) ->
    for id, user of @users
      if user.nickname == nickname
        return user
    return false

  findServerByName: (serverName) ->
    for id, server of @servers
      if server.name == serverName
        return server
    return false

  deleteUsersFromServer: (server, reason) ->
    for id, user of @users
      if user.server != undefined && user.server.id == server.id
        @userQuit user, reason

module.exports = Adapter