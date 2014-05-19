#
# This file is part of Mozart
# (c) Spokela 2014
#
Adapter = require '../adapter'
{Server, User} = require '../structs'

P10_TOKENS = {
  PING:           "G"
  PONG:           "Z",
  SERVER:         "SERVER",
  SERVER_SERVER:  "S",
  END_BURST:      "EB",
  USER:           "N"
}

class IRCu extends Adapter
  connect: ->
    ts = Math.round(new Date()/1000);
    @send "PASS "+ @config.password
    @send "SERVER #{ @config.serverName } 1 #{ ts } #{ ts } J10 5AEEE +s :#{ @config.serverDesc }"
    server = new Server(@config.serverName, 0, ts, ts, @config.serverDesc, false)
    server.numeric = "5AEEE"

    super server

  send: (line) ->
    console.log "> OUT: "+ line
    @socket.write line + "\n"

  serverSend: (msg) ->
    me = @findMyServer()
    @send "#{ me.numeric.substr(0,2) } #{ msg }"

  parse: (line) ->
    console.log "<  IN: "+ line
    split = line.split " "

    # AB G !1400504767.778443 services.spoke.la 1400504767.778443
    if split[1] == P10_TOKENS.PING
      @handlePing split[4]

    # SERVER Dev1.Eu.Spokela.Com 1 1400499149 1400505006 J10 ABA]] +h6 :Spokela, Dev server 1
    # This is our uplink \o/
    if split[0] == P10_TOKENS.SERVER
      s = @serverAdd split[1], split[2], split[3], split[4], "description"
      s.numeric = split[6];
      @findMyServer().parent = s;

    # AB EB
    if split[1] == P10_TOKENS.END_BURST
      server = @findServerByShortNumeric split[0]
      @endOfBurst server

    # AB N neiluj 1 1400499156 ~neiluj Dev1.Eu.Spokela.Com +oiwg B]AAAB ABAAA :julien
    # ABAAA N joe 1400508608
    if split[1] == P10_TOKENS.USER
      # it's a new user connected
      if split[4] != undefined
        server = @findServerByShortNumeric split[0]
        u = @userAdd split[2], split[5], split[6], "realname", server, split[4]

      # it's a nickname change
      else
        @nickChange @findUserByNumeric(split[0]), split[2]

  serverAdd: (serverName, hops, serverTs, linkTs, numeric, description) ->
    server = new Server(serverName, hops, serverTs, linkTs, numeric, description)
    super server
    return server

  userAdd: (nickname, ident, hostname, realname, server, connectionTs) ->
    user = new User(nickname; ident, hostname, realname, server, connectionTs)
    super user
    return user

  endOfBurst: (server) ->
    super server
    return server

  handlePing: (timestamp) ->
    super timestamp

  sendPong: (timestamp) ->
    @serverSend "#{ P10_TOKENS.PONG } #{ timestamp }"

  findServerByShortNumeric: (shortNumeric) ->
    for server in @servers
      if server.numeric.substr(0,shortNumeric.length) == shortNumeric
        return server
    return false

  findMyServer: ->
    for server in @servers
      if server.hops == 0
        return server
    return false

  findUserByNumeric: (numeric) ->
    for user in @users
      if user.numeric == numeric
        return user
    return false

module.exports = IRCu