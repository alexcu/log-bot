SlackClient       = require 'slack-client'
CommandProcessor  = require './command-processor'
###
The log bot class, responsible for human interaction
###
class LogBot
  ###
  @param  [string]  botToken  The auth token to initialise the bot with
  ###
  constructor: (botToken) ->
    slack = new SlackClient botToken, true
    # Login the bot into Slack on creation
    slack.login()

    # Once initialised, begin listening for messages
    slack.on 'open', =>
      slack.on 'message', (message) =>
        channelId = message.channel
        isDMToBot = channelId in (id for id, _ of slack.dms)
        @handleDM message if isDMToBot

  ###
  Handles a DM
  @param  [object]  message The message to parse
  ###
  handleDM: (message) ->
    # Todo, specifically look for help.
    # If admin, use CommandProcessor
    console.log "Got message, ", message.text
    console.log CommandProcessor.parse message.text

# Export the slack bot
module.exports = LogBot