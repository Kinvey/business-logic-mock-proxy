# Copyright (c) 2014, Kinvey, Inc. All rights reserved.
#
# This software is licensed to you under the Kinvey terms of service located at
# http://www.kinvey.com/terms-of-use. By downloading, accessing and/or using this
# software, you hereby accept such terms of service  (and any agreement referenced
# therein) and agree that you have read, understand and agree to be bound by such
# terms of service and are of legal age to agree to such terms with Kinvey.
#
# This software contains valuable confidential and proprietary information of
# KINVEY, INC and is subject to applicable licensing agreements.
# Unauthorized reproduction, transmission or distribution of this file and its
# contents is a violation of applicable laws.
config = require 'config'
should = require 'should'
request = require 'request'
BSON = require('bson').BSONPure.BSON
testUtils = require '../../testUtils'

req = request.defaults {}

baseUrl = "http://#{config.server.address}:#{config.server.port}"
collectionName = "testCollection"

describe 'collectionAccess / count', () ->
  before (done) ->
    testUtils.startServer baseUrl, (forkedProcess) ->
      done()

  after (done) ->
    testUtils.stopServer ->
      done()

  beforeEach (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/insert"
      json:
        entity: [{ propOne: 1, propTwo: 2, unique: 0 }
                 { propOne: 1, propTwo: 2, unique: 1 }
                 { propOne: 2, propTwo: 1, unique: 2 }
                 { propOne: 2, propTwo: 1, unique: 3 }
                 { propOne: 2, propTwo: 3, unique: 4 }]
      (err, res, body) ->
        done()

  afterEach (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/remove"
      json:
        query: {}
      (err, res, body) ->
        done err

  it 'correctly performs a count with an empty query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
      json:
        query: {}
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.should.have.property 'count'
        body.count.should.eql 5
        done()

  it 'correctly performs a count with a non-empty query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
      json:
        query:
          propOne: 1
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.should.have.property 'count'
        body.count.should.eql 2
        done()

  it 'correctly performs a count with a compound query', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
      json:
        query:
          $and: [{ propOne: 2 }
                 { propTwo: 3 }]
      (err, res, body) ->
        return done err if err
        res.statusCode.should.eql 200
        body.should.have.property 'count'
        body.count.should.eql 1
        done()

  it 'correctly performs a count by a single Mongo ObjectID', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query: { unique: 0 }
      (err, res, body) ->
        return done err if err
        body.length.should.eql 1
        objectId = body[0]._id
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
          body: BSON.serialize({ query: { _id: objectId } })
          headers:
            'content-type': 'application/bson'
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            res.statusCode.should.eql 200
            body.should.have.property 'count'
            body.count.should.eql 1
            done()

  it 'correctly performs a count by an array of Mongo ObjectIDs', (done) ->
    req.post
      url: "#{baseUrl}/collectionAccess/#{collectionName}/find"
      json:
        query: { $or: [{ unique: 0 }, { unique: 1 }] }
      (err, res, body) ->
        return done err if err
        body.length.should.eql 2
        object1Id = body[0]._id.toString()
        object2Id = body[1]._id.toString()
        req.post
          url: "#{baseUrl}/collectionAccess/#{collectionName}/count"
          body: BSON.serialize({ query: { _id: { $in: [ object1Id, object2Id ] } } })
          headers:
            'content-type': 'application/bson'
          (err, res, body) ->
            return done err if err
            body = JSON.parse body
            res.statusCode.should.eql 200
            body.should.have.property 'count'
            body.count.should.eql 2
            done()

  describe 'edge cases', () ->
    it "returns 0 when the collection doesn't exist", (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/count"
        json:
          query: {}
        (err, res, body) ->
          return done err if err
          res.statusCode.should.eql 200
          body.should.have.property 'count'
          body.count.should.eql 0
          done()

  describe 'restrictions', () ->
    it 'fails when the query includes the $where operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/count"
        json:
          query:
            $where:
              propOne: 2
        (err, res, body) ->
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()

    it 'fails when the query includes the $query operator', (done) ->
      req.post
        url: "#{baseUrl}/collectionAccess/fakeCollectionName/count"
        json:
          query:
            $query:
              propOne: 2
        (err, res, body) ->
          res.statusCode.should.eql 400
          body.code.should.eql 'DisallowedQuerySyntax'
          done()
