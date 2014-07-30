Module = require 'module'
path = require 'path'
fs = require 'fs-plus'
detective = require 'detective'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'concat', 'Concatenate compiled .js files', ->
    appDir = fs.realpathSync(grunt.config.get('atom.appDir'))
    contentsDir = fs.realpathSync(grunt.config.get('atom.contentsDir'))
    sourceFolder =  path.join(appDir, 'src')

    rendererApiPath = path.resolve(appDir, '..', 'atom', 'renderer', 'api', 'lib')
    commonApiPath = path.resolve(appDir, '..', 'atom', 'common', 'api', 'lib')

    resolve = (moduleName, parentPath) ->
      if moduleName[0] is '.'
        moduleName = path.resolve(path.dirname(parentPath), moduleName)
        try
          require.resolve(moduleName)
        catch error
          moduleName
      else
        originalParentPath = parentPath

        # Built-in modules
        try
          return moduleName if require.resolve(moduleName) is moduleName

        parentPath = path.dirname(parentPath)
        loop
          modulePath = path.join(parentPath, 'node_modules', moduleName)
          try
            return require.resolve(modulePath)
          catch error
            break if parentPath is contentsDir
            parentPath = path.resolve(parentPath, '..')

        rendererPath = path.join(rendererApiPath, "#{moduleName}.js")
        return rendererPath if fs.isFileSync(rendererPath)

        commonPath = path.join(commonApiPath, "#{moduleName}.js")
        return commonPath if fs.isFileSync(commonPath)

        null

    jsFiles = {}

    loadDependencies = (filePath) ->
      return unless fs.isAbsolute(filePath)
      return if path.extname(filePath) in ['.node', '.json']

      filePath = fs.realpathSync(filePath)
      return if jsFiles[filePath]?

      contents = grunt.file.read(filePath)
      requires = {}
      for requireId in detective(contents)
        if resolvedPath = resolve(requireId, filePath)
          requires[requireId] = resolvedPath

      # HACK
      if /less\/lib\/less\/index\.js$/.test(filePath)
        for treeFile in  fs.listSync(path.resolve(filePath, '..', 'tree'), ['.js'])
          requires["./tree/#{path.basename(treeFile, '.js')}"] ?= fs.realpathSync(treeFile)


      jsFiles[filePath] = {contents, requires}
      loadDependencies(modulePath) for moduleId, modulePath of requires

    loadDependencies(jsPath) for jsPath in fs.listSync(sourceFolder, ['.js'])

    slug = """
      var __require = require;
      var __path = __require('path');
      var cache = {};

    """

    for filePath, file of jsFiles
      slug += """

        cache[#{JSON.stringify(filePath)}] = function() {
          var module = {};
          var exports = {};
          module.exports = exports;
          module.paths = global.module.paths;
          cache[#{JSON.stringify(filePath)}] = function() { return module.exports; };

          var requires = #{JSON.stringify(file.requires)};
          var __filename = #{JSON.stringify(filePath)};
          var __dirname = __path.dirname(__filename);

          var require = function(id) {
            var filePath = requires[id];
            if (cache[filePath])
              return cache[filePath]();
            else {
              if (filePath)
                return __require(filePath);
              else
                return __require(id);
            }
          };

          require.resolve = function(id) {
            if (id[0] === '.')
              return __path.resolve(__dirname, id);
            else
              return id;
          };

          require.extensions = __require.extensions;

          (function() {
            #{file.contents}
          }).call(exports);

          return module.exports;
        };

      """

    slug += """

      cache['/private/var/folders/pc/rkhqcn355510xs2lycjj18140000gn/T/atom-build/Atom.app/Contents/Resources/app/src/window-bootstrap.js']();
    """

    grunt.file.write('slug.js', slug)
