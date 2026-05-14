import 'dart:html' as html;

void clearQueryParameters() {
  final cleanUri = Uri.base.replace(queryParameters: {}, fragment: '');
  html.window.history.replaceState(
    null,
    html.document.title,
    cleanUri.toString(),
  );
}
