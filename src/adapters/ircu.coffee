#
# This file is part of Mozart
# (c) Spokela 2014
#
Adapter = require '../adapter'
{Server, User} = require '../structs'

P10_TOKENS = {
  # PING? PONG!
  PING:           "G"
  PONG:           "Z",

  # SERVER TOKENS
  SERVER:         "SERVER",
  SERVER_SERVER:  "S",
  SERVER_QUIT:    "SQ",
  END_BURST:      "EB",
  END_ACK:        "EA",

  # USER TOKENS
  USER:           "N",
  MODE:           "M",
  USER_QUIT:      "Q",
  USER_AWAY:      "A"
}

class IRCu extends Adapter
  connect: ->
    ts = Math.round(new Date()/1000);
    @send "PASS "+ @config.password
    @send "SERVER #{ @config.serverName } 1 #{ ts } #{ ts } J10 5AEEE +s :#{ @config.serverDesc }"
    @serverAdd @config.serverName, 0, ts, ts, @config.serverDesc, "5AEEE", false

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
      s = @serverAdd split[1], split[2], split[3], split[4], @doubleDotStr(split, 8), split[6], split[5] == "J10" ? false : true
      @findMyServer().parent = s;

    # AB EB
    if split[1] == P10_TOKENS.END_BURST
      server = @findServerByShortNumeric split[0]
      @endOfBurst server
      @serverSend "#{ P10_TOKENS.END_ACK }"

    # AB SQ AD 12345670 :reason
    # ADAAD SQ Dev2.Eu.Spokela.Com 0 :neiluj
    if split[1] == P10_TOKENS.SERVER_QUIT
      if split[0].length > 2
        sender = @findUserByNumeric split[0]
      else
        sender = @findServerByShortNumeric split[0]

      if split[2].indexOf('.') != false
        server = @findServerByName split[2]
      else
        server = @findServerByShortNumeric split[2]

      if split.length > 3 && split[3].indexOf(':') == 0
        reason = @doubleDotStr(split, 3)
      else
        reason = undefined

      @serverQuit server, sender, reason

    # AB N neiluj 1 1400499156 ~neiluj Dev1.Eu.Spokela.Com +oiwg B]AAAB ABAAA :julien
    # AB N neiluJ 1 1400509253 ~neiluj Dev1.Eu.Spokela.Com B]AAAB ABAAA :julien
    # ABAAA N joe 1400508608
    if split[1] == P10_TOKENS.USER
      # it's a new user connected
      if split[4] != undefined
        server      = @findServerByShortNumeric split[0]
        modes       = split[7]
        realNameIdx = 9
        account     = ""

        if modes.substr(0,1) == '+'
          realNameIdx++
          if modes.indexOf('r') > -1
            account = split[8]
            realNameIdx++
        else
          modes     = ""

        u = @userAdd split[2], split[5], split[6], @doubleDotStr(split, realNameIdx), server, split[4], split[realNameIdx-1]
        u.changeModes "#{ modes } #{ account }"

      # it's a nickname change
      else
        @nickChange @findUserByNumeric(split[0]), split[2]

    # ABAAA M neiluJ :+ow
    if split[1] == P10_TOKENS.MODE && split[2].indexOf('#') == -1
      if split[0].length > 2
        sender = @findUserByNumeric split[0]
      else
        sender = @findServerByShortNumeric split[0]

      target  = @findUserByNickname split[2]
      modes   = @doubleDotStr(split, 3)
      @umodesChange sender, target, modes

    # ADAAB Q :Quit: byebye
    if split[1] == P10_TOKENS.USER_QUIT
      if split.length > 2 && split[2].indexOf(':') == 0
        reason = @doubleDotStr(split, 2)
      else
        reason = undefined

      @userQuit @findUserByNumeric split[0], reason

    # ADAAB A :brb
    if split[1] == P10_TOKENS.USER_AWAY
      if split.length > 2 && split[2].indexOf(':') == 0
        reason = @doubleDotStr(split, 2)
      else
        reason = false

      u = @findUserByNumeric split[0]
      @userAway u, reason
      console.log u

  serverAdd: (serverName, hops, serverTs, linkTs, description, numeric, bursted = false) ->
    server = new Server serverName, hops, serverTs, linkTs, description, bursted
    server.numeric = numeric
    super server
    return server

  userAdd: (nickname, ident, hostname, realname, server, connectionTs, numeric) ->
    user = new User(nickname; ident, hostname, realname, server, connectionTs)
    user.numeric = numeric
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
    for id, server of @servers
      if server.numeric.substr(0,shortNumeric.length) == shortNumeric
        return server
    return false

  findMyServer: ->
    for id, server of @servers
      if server.hops == 0
        return server
    return false

  findUserByNumeric: (numeric) ->
    for id, user of @users
      if user.numeric == numeric
        return user
    return false

module.exports = IRCu