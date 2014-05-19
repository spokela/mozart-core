#
# This file is part of Mozart
# (c) Spokela 2014
#
class Server
  constructor: (@name, @hops, @timestamp, @linkTimestamp, @description, @bursted = false, @parent = null) ->
    @users = 0

  isUplink: ->
    return @hops == 1 ? true : false

class User
  constructor: (@nickname, @ident, @hostname, @realname, @server, @connectionTs) ->
    @lastNickname = null
    @usermodes = ""
    @fakehost = null
    @account = false

module.exports = {
  Server,
  User
}