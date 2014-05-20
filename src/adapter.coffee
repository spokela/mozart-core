#
# This file is part of Mozart
# (c) Spokela 2014
#
{EventEmitter} = require 'events'
{Channel} = require './structs'

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
  USER_AWAY:          "irc:user-away",
  USER_AUTH:          "irc:user-auth",

  # Channel Events
  CHANNEL_BURST:      "irc:channel-burst",
  CHANNEL_CREATE:     "irc:channel-create",
  CHANNEL_JOIN:       "irc:channel-join",
  CHANNEL_PART:       "irc:channel-part",
  CHANNEL_EMPTY:      "irc:channel-empty",
  CHANNEL_KICK:       "irc:channel-kick",
  CHANNEL_UMODE_CHANGE:   "irc:channel-umode-change",
  CHANNEL_BAN_ADD:    "irc:channel-ban-add"
  CHANNEL_BAN_REMOVE: "irc:channel-ban-remove",
  CHANNEL_MODES_CHANGE:   "irc:channel-modes-change",
  CHANNEL_TOPIC_CHANGE:   "irc:channel-topic-change"
}

class Adapter extends EventEmitter
  constructor: (@config) ->
    @_preParsedTxt = ""
    @servers  = []
    @users    = []
    @channels = []

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
      if serv.parent != null && serv.parent.id == server.id
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

    for id, channelUser of user.channels
      channelUser.channel.removeUser user
      if channelUser.channel.isEmpty()
        delete @channels[channelUser.channel.id]
        @emit IRC_EVENTS.CHANNEL_EMPTY, channelUser.channel

    delete @users[user.id]
    @emit IRC_EVENTS.USER_QUIT, user, reason

  userAway: (user, reason) ->
    if user == false
      throw new Error 'invalid user'

    user.away = reason
    @emit IRC_EVENTS.USER_AWAY, user, reason

  userAuth: (sender, user, account) ->
    if user == false
      throw new Error 'invalid user'

    user.account = account
    @emit IRC_EVENTS.USER_AUTH, user, account, sender

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

  channelAdd: (channel, burst = false) ->
    if channel == false
      throw new Error 'invalid channel'

    @channels[channel.id] = channel
    if burst
      @emit IRC_EVENTS.CHANNEL_BURST, channel
    else
      @emit IRC_EVENTS.CHANNEL_CREATE, channel

  channelJoin: (channel, user, ts) ->
    if channel == false || user == false
      throw new Error 'invalid channel or user'

    channel.addUser user, "", ts
    @emit IRC_EVENTS.CHANNEL_JOIN, channel, user

  channelPart: (channel, user, reason) ->
    if channel == false || user == false
      throw new Error 'invalid channel or user'

    channel.removeUser user
    @emit IRC_EVENTS.CHANNEL_PART, channel, user, reason
    if channel.isEmpty()
      delete @channels[channel.id]
      @emit IRC_EVENTS.CHANNEL_EMPTY, channel

  channelKick: (kicker, channel, user, reason) ->
    if channel == false || user == false || kicker == false
      throw new Error 'invalid channel, kicker or user'

    channel.removeUser user
    @emit IRC_EVENTS.CHANNEL_KICK, channel, user, kicker, reason
    if channel.isEmpty()
      delete @channels[channel.id]
      @emit IRC_EVENTS.CHANNEL_EMPTY, channel

  channelUsermodeChange: (sender, channel, user, modes) ->
    if sender == false || channel == false || user == false
      throw new Error 'invalid sender, channel or user'

    channel.users[user.id].changeModes(modes)
    @emit IRC_EVENTS.CHANNEL_UMODE_CHANGE, channel, user, sender, modes

  channelAddBan: (sender, channel, mask, ts) ->
    if sender == false || channel == false
      throw new Error 'invalid channel or sender'

    ban = channel.addBan mask, sender, ts
    @emit IRC_EVENTS.CHANNEL_BAN_ADD, channel, ban, sender

  channelRemoveBan: (sender, channel, mask) ->
    if sender == false || channel == false
      throw new Error 'invalid channel or sender'

    ban = channel.removeBan mask
    @emit IRC_EVENTS.CHANNEL_BAN_REMOVE, channel, ban, sender

  channelModesChange: (sender, channel, modes, ts) ->
    if sender == false || channel == false
      throw new Error 'invalid channel or sender'

    # don't do nothing here because of protocol-specific modes
    @emit IRC_EVENTS.CHANNEL_MODES_CHANGE, channel, modes, sender, ts

  channelTopicChange: (sender, channel, topic, ts) ->
    if sender == false || channel == false
      throw new Error 'invalid channel or sender'

    if topic.length <= 0
      topic = null

    channel.topic = topic
    channel.topicTs = ts

    @emit IRC_EVENTS.CHANNEL_TOPIC_CHANGE, channel, topic, sender, ts

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

  findMyServer: ->
    for id, server of @servers
      if server.hops == 0
        return server
    return false

  getChannelByName: (name, create = true) ->
    for id, channel of @channels
      if channel.name.toLowerCase() == name.toLowerCase()
        return channel
    if create
      return new Channel name
    else
      return false

module.exports = Adapter