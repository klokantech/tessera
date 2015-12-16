#!/usr/bin/env node
"use strict";

// increase the libuv threadpool size to 1.5x the number of logical CPUs.
process.env.UV_THREADPOOL_SIZE = process.env.UV_THREADPOOL_SIZE || Math.ceil(Math.max(4, require('os').cpus().length * 1.5));

var fs = require("fs"),
    path = require("path");

var async = require("async"),
    cors = require("cors"),
    debug = require("debug"),
    express = require("express"),
    morgan = require("morgan"),
    responseTime = require("response-time");

var serve = require("./lib/app"),
    tessera = require("./lib/index");

debug = debug("tessera");

module.exports = function(opts, callback) {
  var app = express().disable("x-powered-by"),
      tilelive = require("tilelive-cache")(require("tilelive"), {
        size: process.env.CACHE_SIZE || opts.cacheSize,
        sources: process.env.SOURCE_CACHE_SIZE || opts.sourceCacheSize
      });

  callback = callback || function() {};

  // load and register tilelive modules
  require("tilelive-modules/loader")(tilelive, opts);

  if (process.env.NODE_ENV !== "production") {
    // TODO configurable logging per-style
    app.use(morgan("dev"));
  }

  if (opts.uri) {
    app.use(responseTime());
    app.use(cors());
    app.use(express.static(path.join(__dirname, "public")));
    app.use(express.static(path.join(__dirname, "bower_components")));
    app.use(serve(tilelive, opts.uri));

    tilelive.load(opts.uri, function(err, src) {
      if (err) {
        throw err;
      }

      return tessera.getInfo(src, function(err, info) {
        if (err) {
          debug(err.stack);
          return;
        }

        if (info.format === "pbf") {
          app.use("/_", serve(tilelive, "xray+" + opts.uri));
          app.use("/_", express.static(path.join(__dirname, "public")));
          app.use("/_", express.static(path.join(__dirname, "bower_components")));
        }
      });
    });
  }

  if (opts.config) {
    var configPath = path.resolve(opts.config),
        stats = fs.statSync(configPath),
        config = {};

    if (stats.isFile()) {
      config = require(configPath);
    } else if (stats.isDirectory()) {
      config = fs.readdirSync(configPath)
        .filter(function(filename) {
          return path.extname(filename) === ".json";
        })
        .reduce(function(config, filename) {
          var localConfig = require(path.join(configPath, filename));

          return Object.keys(localConfig).reduce(function(config, k) {
            config[k] = localConfig[k];

            return config;
          }, config);
        }, config);
    }

    Object.keys(config).forEach(function(prefix) {
      if (config[prefix].timing !== false) {
        app.use(prefix, responseTime());
      }

      if (config[prefix].cors !== false) {
        app.use(prefix, cors());
      }

      app.use(prefix, express.static(path.join(__dirname, "public")));
      app.use(prefix, express.static(path.join(__dirname, "bower_components")));
      app.use(prefix, serve(tilelive, config[prefix]));
    });

    // serve index.html even on the root
    app.use("/", express.static(path.join(__dirname, "public")));
    app.use("/", express.static(path.join(__dirname, "bower_components")));

    // aggregate index.json on root for multiple sources
    app.get("/index.json", function(req, res, next) {
      var queue = [];
      Object.keys(config).forEach(function(prefix) {
        queue.push(function(callback) {
          var url = config[prefix].source || config[prefix];
          tilelive.load(url, function(err, source) {
            if (err) {
              throw err;
            }

            tessera.getInfo(source, function(err, info) {
              if (err) {
                throw err;
              }

              var domains = [],
                  tilePath = config[prefix].tilePath || "/{z}/{x}/{y}.{format}";

              if (config[prefix].domains && config[prefix].domains.length > 0) {
                domains = config[prefix].domains.split(',');
              }

              info.tiles = serve.getTileUrls(domains, req.headers.host, prefix, tilePath, info.format, req.query.key);
              info.tilejson = "2.0.0";

              callback(null, info);
            });
          });
        });
      });
      return async.parallel(queue, function(err, results) {
        return res.send(results);
      });
    });
  }

  app.listen(process.env.PORT || opts.port, function() {
    console.log("Listening at http://%s:%d/", this.address().address, this.address().port);

    return callback();
  });
};
