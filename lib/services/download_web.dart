import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Triggers a browser download of a text/CSV file.
void downloadTextFile(String filename, String content) {
  final blob = web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.download = filename;
  web.document.body!.appendChild(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
