Logs    = require './logs'
moment  = require 'moment'
Trigger = require './trigger'
util    = require 'util'
Q       = require 'q'
_       = require 'underscore'
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
  Next questions to ask each user
  ###
  @nextQuestions: {}

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
    # Block not created? Create it
    f.block = {} unless f.block?
    # Not the right user or user already in block
    return if user.id isnt f.userId or f.block[f.userId]?
    # Make the resolution block
    f.block[f.userId] = Q.defer() unless f.block[f.userId]?
    @nextQuestions[f.userId] = [] unless @nextQuestions[f.userId]?
    # Match every possible response
    for regEx, action of f.responseActions
      if matches = message.text.match RegExp regEx, 'g'
        # Repeat for each match found
        for match, index in matches
          do (match, index) =>
            # If action is the logging period?
            if typeof action is 'string'
              # If we have encountered a $! action, then resolve this question
              # as the current line of questioning is cancelled
              if action is "$!"
                f.block[f.userId].resolve()
              # Numeric answer
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
                f.block[f.userId].resolve()
            # If action is a second set of questions
            else if typeof action is 'object'
              # Replace $1 in question with the match
              toAsk = action.question.replace /\$1/, match
              # See if there was a dollar one match, and if so we will provide a previousMatch
              previousMatch = if action.question.match(/\$1/)? then match
              @nextQuestions[f.userId].push [ f.logBot, f.userId, toAsk, action.responses, { previousMatch: previousMatch, helpText: action.helpText } ]
              f.block[f.userId].resolve()
      else
        # If this regEx is the last of the response actions and there
        # were no matches? We must've received a bad answer
        if regEx is _.last _.keys f.responseActions
          f.block[f.userId].reject()
    # Handle the block for the user
    f.block[f.userId]?.promise.then ( =>
      # If there are more questions to ask this user?
      if @nextQuestions[f.userId].length > 0
        # Pop the arguments for the next question
        args = @nextQuestions[f.userId].shift()
        # Ask it on the next timeout so that we don't immediately ask it
        # If we don't set it on a timeout then the bot will use the answer
        # that triggered this promise to be the answer for the new trigger
        # created below
        setTimeout ->
          TriggerFirer.firers[f.userId] = new TriggerFirer args[0], args[1], args[2], args[3], args[4]
      # No more questions?
      else
        # We can delete this
        delete @firers[user.id]
      # Regardless, delete the promise block; either we're done or the new
      # trigger created in the next timeout will handle the next question
      delete f.block[f.userId]
    ), ( =>
        # Rejected!
        f.logBot.sendDM "Sorry I don't understand", f.userId
        TriggerFirer.firers[f.userId] = new TriggerFirer f.logBot, f.userId, f.question, f.responseActions, if f.extraParams? then f.extraParams )

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
    # Setup the expiration handler
    @_applyExpirationHandler()
    # Add a handler for this user on a DM response which is received
    unless TriggerFirer.firers[@userId]?
      # Handle the DM once and once only for each user!
      TriggerFirer.firers[@userId] = @
      @logBot.on 'dmResponseReceived', TriggerFirer._responseActionHandler