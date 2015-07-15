express   = require 'express'
uuid      = require 'node-uuid'
{Buffer}  = require 'buffer'
{port}    = require './config'
###
An express server to handle serving of data
###
module.exports = class DataServer
  ###
  The internal express server
  ###
  @_express: express()

  ###
  Setup the /data/:id endpoint
  ###
  @_express.get '/data/:id', (req, res) =>
    id = req.params.id
    # No data exists here?
    unless @_data[id]?
      return res.sendStatus 404
    res.attachment 'data.csv'
    res.send @_data[id].toString()
    # Expire this data endpoint
    delete @_data[id]

  ###
  The actual data server
  ###
  @_server: @_express.listen 3000, =>
    console.log "Data server is up at http://%s:%s/", @_server.address().address, @_server.address().port

  ###
  The urls hash stores data at the given /data/:id endpoint
  ###
  @_data: {}

  ###
  Adds data to the server
  @param  [string|Buffer]  data  Data to store
  @returns  [string]  A unique URI that points to the data
  ###
  @store: (data) =>
    # Convert data into a buffer if need be
    unless Buffer.isBuffer(data)
      data = new Buffer(data)
    id = uuid.v4()
    @_data[id] = data
    "http://#{@_server.address().address}:#{@_server.address().port}/data/#{id}"