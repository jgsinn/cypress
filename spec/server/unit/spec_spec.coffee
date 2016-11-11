require("../spec_helper")

_             = require("lodash")
fs            = require("fs-extra")
str           = require("underscore.string")
path          = require("path")
Promise       = require("bluebird")
through       = require("through")
through2      = require("through2")
spec = require("#{root}lib/controllers/spec")
browserify    = require("browserify")
babelify      = require("babelify")
cjsxify       = require("cjsxify")
streamToPromise = require("stream-to-promise")
appData = require("#{root}lib/util/app_data")

fs = Promise.promisifyAll(fs)

fixturesRoot  = path.resolve(__dirname, "../../", "fixtures/", "server/")

collectResponse = (resStream) ->
  new Promise (resolve, reject) ->
    results = ""
    resStream
    .pipe through (d) => results += d.toString()
    .on 'error', reject
    .on 'end', -> resolve(results)

browserifyFile = (filePath) ->
  streamToPromise(
    browserify(
      entries: [filePath]
      extensions: [".js", ".jsx", ".coffee", ".cjsx"]
    )
    .transform(cjsxify)
    .transform(babelify, {
      plugins: ["add-module-exports"],
      presets: ["latest", "react"],
    })
    .bundle()
  )

describe "lib/controllers/spec", ->
  beforeEach ->
    @config = {
      projectRoot: ""
      integrationFolder: fixturesRoot
      browserify: {
        basedir: fixturesRoot
      }
    }

    @res = through2.obj (chunk, enc, cb) -> cb(null, chunk)

    @res.set  = @sandbox.stub()
    @res.type = @sandbox.stub()
    @res.send = @sandbox.spy()

    @watchers = {
      watchBundle: -> Promise.resolve()
    }

    fs.ensureDirSync(appData.path("bundles"))
    fs.writeFileSync(appData.path("bundles", "sample.js"), ';')

    @handle = (filePath) =>
      spec.handle filePath, {}, @res, @config, (=>), @watchers

  it "sets the correct content type", ->
    @handle("sample.js")

    expect(@res.type)
      .to.have.been.calledOnce
      .and.to.have.been.calledWith('js')

  it "sends the file from the bundles path", ->
    @handle("sample.js")

    collectResponse(@res).then (result) ->
      expect(result).to.equal(";")

  it "sends the error if there is one", ->
    @watchers.watchBundle = -> Promise.reject(new Error("Reason request failed"))

    @handle("sample.js").then =>
      expect(@res.send).to.have.been.called
      expect(@res.send.firstCall.args[0]).to.include("Reason request failed")
