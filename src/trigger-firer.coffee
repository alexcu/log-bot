Logs    = require './logs'
moment  = require 'moment'
Trigger = require './trigger'
util    = require 'util'
module.exports = class TriggerFirer
  ###
  Timeouts for responding to triggers; hash contains the userId as key
  and value as timeout
  ###
  @timeouts: {}

  ###
  Firers for each user as a key/value hash
  ###
  @firers: {}

  ###
  We need a semaphore to block the bot from asking multiple questions at once
  particular if the question is in response to a multi-answer response-based
  question (such as trigger 'Projects')
  ###
  block: null

  ###
  Applies the `responseActions` to the message that was received
  @param  [object]  message   The message text received
  @param  [object]  userId    The user id who responded
  ###
  @_responseActionHandler: (message, user) =>
    # Alias here so it takes up less code
    f = @firers[user.id]
    # Only parse expected user responses
    console.log "Got a message from #{user.profile.real_name} (#{user.id}) => #{message.text} (expected #{f.userId})"
    return if user.id isnt f.userId
    for regEx, action of f.responseActions
      regEx = RegExp regEx, 'g'
      if matches = message.text.match regEx
        # Block not created? Create it
        f.block = require('semaphore')(1) unless f.block?
        # Repeat for each match
        for match, index in matches
          match = match.trim()
          do (match, index) =>
            # If action is the logging period?
            if typeof action is 'string'
              # If we have encountered a $! action, then restart
              # from initial questions and responses
              if action is "$!"
                TriggerFirer.firers[f.userId] = new TriggerFirer f.logBot, f.userId, f.question, f.responseActions, {helpText: f.helpText}
              else
                # Need to replace a workDay with the actual value it has as defined
                # by the trigger manager that holds this trigger (i.e., by LogBot)
                action = action.replace /workDay/, f.logBot.triggerManager.workDay
                action = action.replace /\$1/, match
                # Evaluate the mathematical expression in the action
                hours = parseFloat(eval action)
                project = (if f.extraParams? then f.extraParams.previousMatch)
                # Actually insert the log!
                Logs.insert f.userId, hours, project
                # Only clear the timeout when the question is resolved
                clearTimeout @timeouts[f.userId]
                f.logBot.sendDM "Thank you. I have logged *#{hours.toFixed(2)} hours* for #{if project? then project else "your work"}. :simple_smile:", f.userId
              # Leave a token to unblock for the next question to be asked,
              # granted it isn't the last question
              f.block[f.userId].leave() if f.block.current isnt 0
            # If action is a second set of questions
            else if typeof action is 'object'
              # Take acquisition of the asking block
              f.block.take =>
                # Replace $1 in question with the match
                toAsk = action.question.replace /\$1/, match
                # See if there was a dollar one match, and if so we will provide a previousMatch
                previousMatch = if action.question.match(/\$1/)? then match
                TriggerFirer.firers[f.userId] = new TriggerFirer f.logBot, f.userId, toAsk, action.responses, { previousMatch: previousMatch, helpText: action.helpText }
    f.logBot.sendDM "Sorry I don't understand", f.userId
    console.log "xxxxxxx"
    TriggerFirer.firers[f.userId] = new TriggerFirer f.logBot, f.userId, f.question, f.responseActions, if f.extraParams? then f.extraParams

  ###
  Applies the trigger expiration
  ###
  _applyExpirationHandler: =>
    # Expire that handler after six hours
    expiration = moment.duration(6, 'hours').asMilliseconds()
    if TriggerFirer.timeouts[@userId]?
      clearTimeout TriggerFirer.timeouts[@userId]
    timeoutFn = =>
      # Remove the listener for any more responses
      @logBot.sendDM "I'll ask you another time :pensive:", @userId
      @logBot.removeListener 'dmResponseReceived', TriggerFirer._responseActionHandler
    TriggerFirer.timeouts[@userId] = setTimeout timeoutFn, expiration

  ###
  @param  [string]  logBot            The log bot used to construct the firer
  @param  [string]  userId            The user id to perform the trigger on
  @param  [string]  question          The question to prompt
  @param  [object]  responseActions   The expected response/action pairs
  @param  [object]  extraParams       Extra parameters to provide to the trigger, optional
  ###
  constructor: (@logBot, @userId, @question, @responseActions, @extraParams) ->
    # Send the question (with helpText if applicable)
    messageToSend = if @extraParams?.helpText? then "#{@question}\n>#{@extraParams.helpText}" else @question
    @logBot.sendDM messageToSend, @userId, true
    console.log "TF: Trigger fired for #{@logBot.slack.getUserByID(@userId).profile.real_name}"
    # Setup the expiration handler
    @_applyExpirationHandler()
    # Add a handler for this user on a DM response which is received
    console.log 3
    unless TriggerFirer.firers[@userId]?
      # Handle the DM once and once only for each user!
      TriggerFirer.firers[@userId] = @
      @logBot.on 'dmResponseReceived', TriggerFirer._responseActionHandler