SlackClient       = require 'slack-client'
CommandProcessor  = require './command-processor'
Users             = require './users'
_                 = require 'underscore'
###
The log bot class, responsible for human interaction
###
module.exports = class LogBot
  ###
  @param  [string]  botToken  The auth token to initialise the bot with
  ###
  constructor: (botToken) ->
    # Setup the command processor
    @_cmdProcessor = new CommandProcessor
    @_cmdProcessor.on 'commandSuccess', (msg) ->
      console.log "SUCCESS: #{msg}"
    @_cmdProcessor.on 'commandFailed', (msg) ->
      console.log "FAILED: #{msg}"
    # Setup the slack client
    @_slack = new SlackClient botToken, true
    # Login the bot into Slack on creation
    @_slack.login()
    # Whenever there is a new user to the team, create a new User type for them
    @_slack.on 'userChange', =>
      @_updateUsers()
    # Handle slack errors
    @_slack.on 'error', (err) =>
      console.log "An error has occurred : #{JSON.stringify err}"
    # Once initialised, begin listening for messages
    @_slack.on 'open', =>
      console.log "#{@_slack.self.name} has connected"
      # Update it anyway on creation of the bot to get first-time users
      @_updateUsers()
      @_slack.on 'message', (message) =>
        channelId = message.channel
        isDMToBot = channelId in (id for id, _ of @_slack.dms)
        @_handleDM message if isDMToBot
  ###
  Updates the team DB store
  ###
  _updateUsers: =>
    # Get all users we currently have
    Users.all().then (existingUsers) =>
      existingUserIds = _.pluck existingUsers, 'id'
      existingUserIds
      # Create each slack user who is not already created as a User type
      newUsers = _.select @_slack.users, (user) ->
        isBot = user.is_bot or user.profile.real_name is 'slackbot'
        not (user.id in existingUserIds or isBot)
      # Add in the new user
      Users.add user.id, user.profile for user in newUsers

  ###
  Handles a DM
  @param  [object]  message The message to parse
  ###
  _handleDM: (message) =>
    # Todo, specifically look for help.
    # If admin, use CommandProcessor
    @_cmdProcessor.parse message.text