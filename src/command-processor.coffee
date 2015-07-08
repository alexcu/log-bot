Users           = require './users'
Roles           = require './roles'
{EventEmitter}  = require 'events'
###
This class is responsible for handling bot admin commands
###
module.exports = class CommandProcessor extends EventEmitter
  ###
  RegExp's for the kinds of parameters accepted in the processor
  ###
  PARAMS =
    USER: /<@([A-Z0-9]+)>/g                   # A slack user
    ROLE: /(?:(?:["“'‘])([A-Z\_\s]+)(?:["”'’]))/g   # A role (wrapped in quotes)

  ###
  Command replacement matches. Plurals must come first such that
  they will reduce down to their singular equivalents.
  ###
  MATCH_REPLACEMENTS =
    '[USERS]': /([USER],?\s?)+/
    '[USER]' : PARAMS.USER
    '[ROLES]': /([ROLE],?\s?)+/
    '[ROLE]' : PARAMS.ROLE

  ###
  Commands mapped to their functions
  Where [USER] is present, a slack user will be matched
  Where [ROLE] is present, a user role will be matched
  ###
  COMMANDS =
    # Role-based commands
    'ASSIGN [USER] ROLE [ROLE]' : 'assignUserRole'
    'ADD ROLE [ROLES]'          : 'addRole'
    'DROP ROLE [ROLES]'         : 'dropRole'
    'GET ROLE FOR [USER]'       : 'getRolesForUsers'
    'GET ROLES FOR [USERS]'     : 'getRolesForUsers'
    'GET ALL ROLES'             : 'getAllRoles'
    # Log-based commands
    'GET LOGS FOR [USERS]'      : 'getLogsForUsers'
    'GET LOGS'                  : 'getAllLogs'

  ###
  Assigns the user provided a role
  @param  [object]  args  The command args
  ###
  __assignUserRole: (args) =>
    userId  = args.users[0]
    role    = args.roles[0]
    Users.assignRole(userId, role)
      .then (success) =>
        @_success success
      .fail (err) =>
        @_fail err
  __addRole: (args) ->
    roles = args.roles
    while roles.length > 0
      role = roles.shift()
      Roles.add(role)
        .then (success) =>
          @_success success
        .fail (err) =>
          @_fail err
  __dropRole: (args) ->
    roles = args.roles
    while roles.length > 0
      role = roles.shift()
      Roles.drop(role)
        .then (success) =>
          @_success success
        .fail (err) =>
          @_fail err
  __getAllRoles: (args) ->
    Roles.all().then (roles) =>
      @_success "Here are all the roles: \"#{roles.join('\", \"')}\""
  __getRolesForUsers: (args) ->
    users = args.users
    while users.length > 0
      userId = users.shift()
      Users.find(userId)
        .then (user) =>
          hasRole = user.role?
          if hasRole
            @_success "Role for #{user.profile.real_name} is \"#{user.role}\""
          else
            @_success "#{user.profile.real_name} is not yet assigned a role"
        .fail (err) =>
          @_fail err
  __getLogsForUsers: (args) ->
    "TODO: Implement __getLogsForUsers\t args = (#{JSON.stringify args})"
  __getAllLogs: (args) ->
    "TODO: Implement __getAllLogs\t args = (#{JSON.stringify args})"

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
    @emit 'commandFailed', message

  ###
  Emits a command success message
  @param  [string]  message Success message
  ###
  _success: (message) =>
    @emit 'commandSuccess', message


  ###
  Checks for a match between the input and the command provided
  @param  [string]  input Input string
  @param  [string]  command Regular Expression command
  @returns  [boolean] True on match, false otherwise
  ###
  _match: (input, command) =>
    matches = input.match(@_regExpForCommand command)
    matches? and matches.length > 0

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
  Returns a humanised list of available commands
  @returns  [array]  A list of each possible command
  ###
  humanisedCommands: ->
    (key for key of COMMANDS)

  ###
  Parses the input string for a command
  @param  [string]  input Input string
  @returns  [string]  A result string
  ###
  parse: (input) =>
    if input?
      input = input.toUpperCase()
      for command, func of COMMANDS
        if @_match input, command
          params = @_stripParams input
          try
            # Execute the command
            @['__' + func](params)
          catch e
            @_fail e.message
    else
      @_fail "Invalid admin command!"