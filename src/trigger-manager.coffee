{triggerFile} = require './config'
fs            = require 'fs'
{CronJob}     = require 'cron'
Trigger       = require './trigger'
Q             = require 'q'

###
The trigger manager class is responsible for managing triggers
###
module.exports = class TriggerManager
  ###
  Defines the number of hours defined in a work day.
  Loaded in on `loadTriggerCache` method
  ###
  workDay: null
  ###
  The triggers I know about
  ###
  triggers: {}
  ###
  Loads the trigger cache and stores information contained here
  to be used as a one-off load process for later construction
  of other TriggerManager instances
  ###
  @loadTriggerCache: ->
    d = Q.defer()
    triggerCache = {}
    throw Error "No `triggerFile` key specified in `config.json`" unless triggerFile?
    # The constructor for the trigger manager will validate the trigger file on load
    fs.readFile triggerFile, (err, data) =>
      # Couldn't find the file
      throw Error "Error when loading `trigger.json`: #{err.message}" if err?
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
        triggerKey = triggerKey.trim().toUpperCase();
        throw Error "Duplicate trigger key \"#{triggerKey}\"!" if triggerCache[triggerKey]?
        throw Error "Trigger keys only contain alphanumeric, spaces, dashes and underscore characters (invalid key \"#{triggerKey}\")" unless /^[A-Z\_\s\-\d]+$/.test triggerKey
        # Check root level keys
        for key, type of {question: 'string', responses: 'object', conditions: 'object'}
          throw Error "Key `#{key}` missing from trigger #{triggerKey}" unless trigger[key]?
          throw Error "Key `#{key} should be a #{type}" if typeof trigger[key] isnt type
        question    = trigger.question
        responses   = trigger.responses
        conditions  = trigger.conditions
        helpText    = trigger.helpText
        throw Error "Key `helpText` should be a string type" if helpText? and typeof helpText isnt 'string'
        # Time is currently required
        throw Error "Required `time` conditional missing from trigger #{triggerKey}" unless conditions.time?
        # Validate the conditions
        for key, value of conditions
          # Check that we've been given a valid cron time
          if key is 'time'
            try
              new CronJob '00' + value
            catch e
              throw Error "Invalid cron time for `time` conditional"
          if key is 'loggedInToday'
            throw Error "Conditional `loggedInToday` must be boolean" if typeof value isnt 'boolean'
        triggerCache[triggerKey] =
          triggerKey: triggerKey
          question:   question
          helpText:   helpText
          responses:  responses
          conditions: conditions
      d.resolve [triggerCache, workDay]
    d.promise
  ###
  @param  [LogBot]  logBot  The log bot that created the trigger manager
  ###
  constructor: (logBot) ->
    TriggerManager.loadTriggerCache().spread (triggerCache, workDay) =>
      @workDay = workDay
      for triggerKey, cache of triggerCache
        @triggers[triggerKey] = new Trigger logBot, cache.triggerKey, cache.question, cache.helpText, cache.responses, cache.conditions