var wrap = function(cache, filePath, requires) {
  cache[filePath] = function() {
    var cacheRequire = function() {
      var module = {};
      var exports = {};
      module.exports = exports;

      var require = function() { return cache[requires[filePath]] };
      return module.exports;
    };

    var exports = cacheRequire();
    cache[filePath] = function() { return exports; };
    return exports;
  };
}
