Users           = require './users'
Roles           = require './roles'
Logs            = require './logs'
{EventEmitter}  = require 'events'
_               = require 'underscore'
DataServer      = require './data-server'
Q               = require 'q'

###
This class is responsible for handling bot admin commands
###
module.exports = class CommandProcessor extends EventEmitter
  ###
  RegExp's for the kinds of parameters accepted in the processor
  ###
  PARAMS =
    USER: /<@([A-Z0-9]+)>/g                               # A slack user
    ROLE: /(?:(?:["“'‘])([A-Z\_\s\-\d]+)(?:["”'’]))/g     # A role (wrapped in quotes)
    TRIGGER: /(?:(?:["“'‘])([A-Z\_\-\s\d]+)(?:["”'’]))/g  # A trigger (wrapped in quotes)

  ###
  Command replacement matches. Plurals must come first such that
  they will reduce down to their singular equivalents.
  ###
  MATCH_REPLACEMENTS =
    '[USERS]': /([USER],?\s?)+/
    '[USER]' : PARAMS.USER
    '[ROLES]': /([ROLE],?\s?)+/
    '[ROLE]' : PARAMS.ROLE
    '[TRIGGER]': PARAMS.TRIGGER

  ###
  Commands mapped to their functions
  Where [USER] is present, a slack user will be matched
  Where [ROLE] is present, a user role will be matched
  Where [ROLE] is present, a trigger will be matched
  ###
  COMMANDS =
    # Role-based commands
    'ASSIGN [USER] ROLE [ROLE]':
      description:  'Assigns the provided user the given role'
      func:         'assignUserRole'
    'ADD ROLES? [ROLES]':
      description:  'Makes me aware of a new role(s)'
      func:         'addRoles'
    'DROP ROLES? [ROLES]':
      description:  'Drops a role(s) that I currently know of. \
                     Warning: any user that has this role will be stripped of that role.'
      func:         'dropRoles'
    'GET ROLES? FOR [USERS]':
      description:  'Gets the role(s) for the given user(s)'
      func:         'getRolesForUsers'
    'GET ALL ROLES':
      description:  'Gets every role that I know about'
      func:         'getAllRoles'
    # Log-based commands
    'GET LOGS? FOR [USERS]':
      description:  'Gets each log the user(s) provided'
      func:         'getLogsForUsers'
    'GET LOGS? FOR [ROLES]':
      description:  'Gets each log for every user that has the role(s) provided'
      func:         'getLogsForRoles'
    'GET ALL LOGS':
      description:  'Gets every log that I know about'
      func:         'getAllLogs'
    # Triggers
    'ASSIGN [ROLE] TRIGGER [TRIGGER]':
      description:  'Assigns the role provided a new trigger'
      func:         'assignRoleTrigger'
    'GET ALL TRIGGERS':
      description:  'Gets every trigger that I know about'
      func:         'getAllTriggers'
    'GET TRIGGERS? FOR [ROLES]':
      description:  'Gets the trigger(s) associated to the given role(s)'
      func:         'getTriggersForRoles'
    # Help
    'HELP':
      description:  'Shows this help menu'
      func:         'getHelp'
  ###
  Assigns the user provided a role
  @param  [object]  args  The command args
  ###
  __assignUserRole: (args) =>
    userId  = args.users[0]
    role    = args.roles[0]
    Users.assignRole(userId, role)
    .then ((success)  => @_success success),
          ((err)      => @_fail err)
  ###
  Adds a new role
  @param  [object]  args  The command args
  ###
  __addRoles: (args) ->
    d = Q.defer()
    responses = []
    roles = args.roles
    while roles.length > 0
      do (roles) =>
        role = roles.shift()
        last = roles.length is 0
        Roles.add(role)
        .then ((success)  => responses.push success; d.resolve [@_success, responses.join ', '] if last),
              ((err)      => d.resolve [@_fail, err])
    d.promise.spread (func, msg) =>
      func msg
  ###
  Drops an existing role
  @param  [object]  args  The command args
  ###
  __dropRoles: (args) ->
    d = Q.defer()
    responses = []
    roles = args.roles
    while roles.length > 0
      do (roles) =>
        role = roles.shift()
        last = roles.length is 0
        Roles.drop(role)
        .then ((success)  => responses.push success; d.resolve [@_success, responses.join ', '] if last),
              ((err)      => d.resolve [@_fail, err])
    d.promise.spread (func, msg) =>
      func msg
  ###
  Gets all roles
  ###
  __getAllRoles: ->
    Roles.names().then (roles) =>
      if roles.length is 0
        return @_success "There are no roles I know of"
      @_success "Here are all the roles: \"#{roles.join('\", \"')}\""
  ###
  Gets the roles for the given users
  @param  [object]  args  The command args
  ###
  __getRolesForUsers: (args) ->
    d = Q.defer()
    responses = []
    users = args.users
    formatMsg = (user) =>
      if user.role?
        return "Role for #{user.profile.real_name} is \"#{user.role}\""
      else
        return "#{user.profile.real_name} is not yet assigned a role"
    while users.length > 0
      do (users) =>
        userId = users.shift()
        last   = users.length is 0
        Users.find(userId)
        .then ((user) =>
                responses.push formatMsg user
                d.resolve [@_success, responses.join ', '] if last),
              ((err)  => d.resolve [@_fail, "No such user found"] )
    d.promise.spread (func, msg) =>
      func msg

  ###
  Gets the logs for the given user(s)
  @param  [object]  args  The command args
  ###
  __getLogsForUsers: (args) =>
    userIds = args.users
    Logs.forUsers(userIds).then (logs) =>
      @_fail "No logs found" if logs.length is 0
      Logs.asCSV(logs).then (csv) =>
        @_success 'One-time download link: ' + DataServer.store csv
  ###
  Gets the logs for the given role(s)
  @param  [object]  args  The command args
  ###
  __getLogsForRoles: (args) =>
    roles = args.roles
    Logs.forRoles(roles).then (logs) =>
      @_fail "No logs found" if logs.length is 0
      Logs.asCSV(logs).then (csv) =>
        @_success 'One-time download link: ' + DataServer.store csv
  ###
  Gets all logs available
  @param  [object]  args  The command args
  ###
  __getAllLogs: (args) =>
    Logs.all().then (logs) =>
      @_fail "No logs found" if logs.length is 0
      Logs.asCSV(logs).then (csv) =>
        @_success 'One-time download link: ' + DataServer.store csv
  ###
  Assigns the role the provided trigger
  @param  [object]  args  The command args
  ###
  __assignRoleTrigger: (args) ->
    triggerKey  = args.triggers[1]
    role        = args.roles[0]
    Roles.associateTrigger(role, triggerKey, @_logBot.triggerManager)
      .then ((success) => @_success success), ((err) => @_fail err)
  ###
  Gets the trigger for the given role
  @param  [object]  args  The command args
  ###
  __getTriggersForRoles: (args) ->
    d = Q.defer()
    roles = args.roles
    responses = []
    formatMsg = (role) =>
      if role.trigger?
        return "Trigger for \"#{role.name}\" is \"#{role.trigger}\""
      else
        return "\"#{role.name}\" has no trigger associated to it"
    while roles.length > 0
      do (roles) =>
        roleName = roles.shift()
        last = roles.length is 0
        Roles.find(roleName)
        .then ((role) =>
                responses.push formatMsg role
                d.resolve [@_success, responses.join ', '] if last),
              ((err)  => d.resolve [@_fail, "No such role \"#{roleName}\""] )
    d.promise.spread (func, msg) =>
      func msg


  ###
  Gets all triggers
  ###
  __getAllTriggers: ->
    triggers = (key.toUpperCase() for key of @_logBot.triggerManager.triggers)
    if triggers.length is 0
      return @_success "There are no triggers I know of"
    @_success "Here are all the triggers: \"#{triggers.join('\", \"')}\""
  ###
  Gets descriptions for every command
  ###
  __getHelp: ->
    string = "I understand all of these commands...\n"
    for command, commandData of COMMANDS
      commandStr = command.replace "S?", "(S)"
      string += "`#{commandStr}`\n_#{commandData.description}_\n\n"
    @_success string

  ###
  Generates a Regular Expression for the given command by converting its
  matched replacements with the replacements to match
  @param  [string]  command The input command
  @returns  [RegExp]  A regular expression representing the command
  ###
  _regExpForCommand: (command) ->
    # Replace param match replacements with actual RegEx
    for match, regExp of MATCH_REPLACEMENTS
      # Replace each match with it's matched RegExp
      command = command.replace match, regExp.source
    # Return the command as a RegExp
    RegExp(command)

  ###
  Emits a command fail message
  @param  [string]  message Fail message
  ###
  _fail: (message) =>
    @emit 'commandParsed', { message: message, success: false }

  ###
  Emits a command success message
  @param  [string]  message Success message
  ###
  _success: (message) =>
    @emit 'commandParsed', { message: message, success: true }

  ###
  Checks for a match between the input and the command provided
  @param  [string]  input Input string
  @param  [string]  command Regular Expression command
  @returns  [boolean] True on match, false otherwise
  ###
  _match: (input, command) =>
    matches = input.match(@_regExpForCommand command)
    matches?.length > 0

  ###
  Strips a parameter list out of the command from all possible parameters
  @param  [string]  input Input string to parse
  @returns  [array] An array of user ids stripped
  ###
  _stripParams: (input) ->
    stripped = {}
    for paramType, regExp of PARAMS
      paramType = paramType.toLowerCase() + 's'
      while (match = regExp.exec(input))
        value = match[1]
        continue unless value?
        stripped[paramType] = [] unless stripped[paramType]?
        stripped[paramType].push value
    stripped

  ###
  Parses the input string for a command
  @param  [string]  input Input string
  ###
  parse: (input) =>
    if input?
      input = input.toUpperCase()
      for command, commandData of COMMANDS
        if @_match input, command
          params = @_stripParams input
          try
            # Execute the command
            return @['__' + commandData.func](params)
          catch e
            return @_fail  "Internal error: " + e.message + "\n\n```" + e.stack + "```" +
                           "\n\nReport an issue? https://github.com/alexcu-/log-bot/issues"
      @_fail "Invalid admin command!"

  ###
  @param  [LogBot]  logBot  The log bot connected to this command processor
  ###
  constructor: (@_logBot) ->
    return