// Stub for non-web platforms
class JsStub {
  dynamic get context => throw UnsupportedError('JS context not available on this platform');
}

final js = JsStub();