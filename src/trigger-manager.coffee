{triggerFile} = require './config'
fs            = require 'fs'
{CronJob}     = require 'cron'
Trigger       = require './trigger'
###
The trigger manager class is responsible for managing triggers
###
module.exports = class TriggerManager
  ###
  The triggers I know about
  ###
  triggers: {}
  ###
  @param  [LogBot]  logBot  The log bot that created the trigger manager
  ###
  constructor: (logBot) ->
    # The constructor for the trigger manager will validate the trigger file on load
    fs.readFile triggerFile, (err, data) =>
      # Couldn't find the file
      throw err if err?
      # Read in the JSON, and strip out comments and backslash backslashes
      # to make our users happy :-)
      jsonStr = data.toString().replace(/\/\/([^\n])*/g,'').replace(/\\/g, '\\\\')
      rawTriggers = undefined
      try
        rawTriggers = JSON.parse jsonStr
      catch e
        throw Error "Bad JSON for triggers. Error: #{e.message}"
      # Grab out the workDay
      workDay = rawTriggers.workDay
      throw Error "Key `workDay` missing in triggers.json" unless workDay?
      # Grab out each of the triggers
      triggers = rawTriggers.triggers
      throw Error "Key `triggers` missing in triggers.json" unless triggers?
      throw Error "Triggers should be an object" if typeof triggers isnt 'object'
      # Validate each trigger
      for triggerKey, trigger of triggers
        throw Error "Trigger key #{triggerKey} already exists!" if @triggers[triggerKey]?
        # Check root level keys
        for key, type of {question: 'string', responses: 'object', conditions: 'object'}
          throw Error "Key `#{key}` missing from trigger #{triggerKey}" unless trigger[key]?
          throw Error "Key `#{key} should be a #{type}" if typeof trigger[key] isnt type
        question    = trigger.question
        responses   = trigger.responses
        conditions  = trigger.conditions
        # Time is currently required
        throw Error "Required `time` conditional missing from trigger #{triggerKey}" unless conditions.time?
        # Validate the conditions
        for key, value of conditions
          # Check that we've been given a valid cron time
          if key is 'time'
            try
              new CronJob value
            catch e
              throw Error "Invalid cron time for `time` conditional"
          if key is 'loggedInToday'
            throw Error "Conditional `loggedInToday` must be boolean" if typeof value isnt 'boolean'
        @triggers[triggerKey] = new Trigger logBot, triggerKey, question, responses, conditions