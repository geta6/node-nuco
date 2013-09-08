# Dependency

os = require 'os'
fs = require 'fs'
path = require 'path'
util = require 'util'
{exec} = require 'child_process'
cluster = require 'cluster'

seek = (dir, type = 'd', only = /.*/, save = /^(\.|node_modules|public)/) ->
  res = []
  for f in fs.readdirSync dir
    continue if save.test f
    f = path.resolve dir, f
    switch type
      when 'f'
        if (fs.statSync f).isDirectory()
          res = res.concat seek f, type, only, save
        else
          res.push f if only.test f
      when 'd'
        if (fs.statSync f).isDirectory()
          res.push f if only.test f
          res = res.concat seek f, type, only, save
  return res

nuco = (main, options = {}) ->

  options.bar or= no
  options.env or= 'development'
  options.port or= 3000
  options.forks or= 'auto'
  options.color or= no
  options.watch or= no
  options.asset or= null

  # Env

  process.env.PORT or= options.port
  process.env.NODE_ENV or= options.envs

  # Bar

  if options.bar
    stdout = process.stdout.write
    stderr = process.stderr.write

    message = ->
      msg = if process.env.__nucoenv is 'master' then '\x1b[35m' else '\x1b[36m'
      now = new Date()
      # now = "#{('00'+(now.getMonth()+1)).slice(-2)}/#{('00'+now.getDate()).slice(-2)} #{('00'+now.getHours()).slice(-2)}:#{('00'+now.getMinutes()).slice(-2)}:#{('00'+now.getSeconds()).slice(-2)}"
      now = "#{('00'+now.getHours()).slice(-2)}:#{('00'+now.getMinutes()).slice(-2)}:#{('00'+now.getSeconds()).slice(-2)}"
      msg+= head = now + ' ' + process.env.__nucoenv
      msg+= ' ' for i in [0...(20 - head.length)]
      return msg

    process.stdout.write = ->
      if arguments.callee.caller.toString? and 80 is arguments.callee.caller.toString().length
        arguments[0] = "#{message()}| \x1b[0m#{arguments[0]}"
      else
        arguments[0] = "#{message()}|  \x1b[0m#{arguments[0]}"
      stdout.apply @, arguments

    process.stderr.write = ->
      if arguments.callee.caller.toString? and 80 is arguments.callee.caller.toString().length
        arguments[0] = "#{message()}| \x1b[0m#{arguments[0]}"
      else
        arguments[0] = "#{message()}|  \x1b[0m#{arguments[0]}"
      stderr.apply @, arguments

  # Colorize

  if options.color
    for method in ['log', 'info', 'warn', 'error']
      do (method) ->
        origin = console[method]
        console[method] = ->
          data = switch method
            when 'log' then '\x1b[32m'
            when 'info' then '\x1b[34m'
            when 'warn' then '\x1b[33m'
            when 'error' then '\x1b[31m'
            else '\x1b[0m'
          args = Array::slice.call arguments
          args.unshift data
          args.push '\x1b[0m'
          origin.apply @, args

  # Clustering

  if cluster.isMaster

    process.env.__nucoenv = 'master'

    cluster.on 'online', (worker) ->
      console.log 'worker online'

    cluster.on 'listening', (worker) ->
      console.log "worker listening on port #{process.env.PORT}"

    cluster.on 'exit', (worker) ->
      console.warn 'worker exit'
      for worker, i in workers
        unless worker
          workers[i] = cluster.fork({__nucoenv: "worker.#{i+1}"}).process.pid

    options.forks = parseInt options.forks
    options.forks = os.cpus().length unless options.forks

    workers = Array options.forks

    for i in [0...options.forks]
      workers[i] = cluster.fork({__nucoenv: "worker.#{i+1}"}).process.pid

    # Watch

    if options.watch

      process.on 'nuco::restart', ->
        for worker, i in workers when worker
          delete workers[i]
          process.kill worker

      save = /^(\.|node_modules|public)/
      if options.asset
        save = new RegExp "^(\\.|node_modules|#{options.asset}|public)"
      for dir in seek '.', 'd', /.*/, save
        do (dir) ->
          fs.watch dir, (act, file) ->
            if /\.(js|coffee)$/.test file
              console.info act, file
              process.emit 'nuco::restart'

    # Asset

    if options.asset
      srcpath = path.resolve options.asset
      dstpath = path.resolve 'public'
      find = (name) ->
        file = "./node_modules/.bin/#{name}"
        return file if fs.existsSync file
        file = "./node_modules/nuco/node_modules/.bin/#{name}"
        return file if fs.existsSync file
        file = "../.bin/#{name}"
        return file if fs.existsSync file
        return name

      bin =
        coffee: find 'coffee'
        stylus: find 'stylus'
        uglify: find 'uglifyjs'
        sqwish: find 'sqwish'

      compile = (src) ->
        ini = new Date
        dst = src.replace srcpath, dstpath
        return fs.unlinkSync dst unless fs.existsSync src
        return if /^\./.test src
        if /\.js$/.test src
          fs.createReadStream(src).pipe fs.createWriteStream dst
          exec "echo `#{bin.uglify} < #{dst}` > #{dst}", ->
            console.info 'compiled', "(#{new Date - ini} ms)", src.replace "#{srcpath}/", ''
        if /\.coffee$/.test src
          dst = dst.replace /\.coffee$/, '.js'
          exec "#{bin.coffee} -p #{src} > #{dst}", (err, stdout, stderr) ->
            console.warn stderr if stderr
            exec "echo `#{bin.uglify} < #{dst}` > #{dst}", ->
              console.info 'compiled', "(#{new Date - ini} ms)", src.replace "#{srcpath}/", ''
        if /\.css$/.test src
          fs.createReadStream(src).pipe fs.createWriteStream dst
          exec "#{bin.sqwish} #{dst} -o #{dst}", ->
            console.info 'compiled', "(#{new Date - ini} ms)", src.replace "#{srcpath}/", ''
        if /\.styl$/.test src
          dst = dst.replace /\.styl$/, '.css'
          exec "#{bin.stylus} -c -U -I node_modules < #{src} > #{dst}", (err, stdout, stderr) ->
            console.warn stderr if stderr
            exec "#{bin.sqwish} #{dst} -o #{dst}", ->
              console.info 'compiled', "(#{new Date - ini} ms)", src.replace "#{srcpath}/", ''

      for file in seek options.asset, 'f', /\.(js|coffee|css|styl)$/
        compile file
      for dir in seek '.', 'd', new RegExp options.asset
        do (dir) ->
          fs.watch dir, (act, file) ->
            if /\.(js|coffee|css|styl)$/.test file
              compile path.resolve dir, file

    return

  # Main
  require path.resolve main

nuco.isnuco = nuco.isNuco = ->
  return process.env.__nucoenv?

module.exports = exports = nuco
