Q               = require 'q'
{EventEmitter}  = require 'events'

###
A one-to-one conversation between the bot and human, initiated by the bot
###
module.exports = class Conversation extends EventEmitter
  ###
  @param [LogBot] logBot  The log bot that will handle this conversation
  @param [string] userId  The id of the person to DM to
  @param [string] initialQuestion The initial question that starts the conversation
  @param [object] responseActions The response / action pair
  ###
  constructor: (@logBot, userId, @initialQuestion, @responseActions) ->
    @user = @logBot.users[userId]
    unless @user?
      throw Error "User id #{userId} not found!"
    # Load the DM channel from slack DMs if there
    @_dmChannel = (dm for id, dm of slack.dms when dm.user is @user.id)[0]
    # When I get a message back from a human
    @logBot.on 'message', (message) =>
      if message.getChannelType() is "DM" and message.user is userId
        text = message.text
        acceptedResponses = (response for response, action of @responseActions)
        text.match acceptedResponses #x
  ###
  Send a message in a DM to the user
  @param [string] message The message to send
  ###
  sendMessage: (message) =>
    # Load the DM channel from slack DMs if there
    send = =>
      @_dmChannel.send message
    # If we need to open a new DM channel, then we open one
    unless @_dmChannel?
      d = Q.defer()
      slack.openDM @user.id, (dm) ->
        @_dmChannel = slack.dms[dm.channel.id]
        d.resolve()
      d.promise.then send
    else
      send()