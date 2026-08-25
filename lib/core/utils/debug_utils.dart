bool get kDebugModeSafe {
  var debug = false;
  assert(() {
    debug = true;
    return true;
  }());
  return debug;
}
