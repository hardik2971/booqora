import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser helpers (web-only app).
class Browser {
  static void downloadBytes(Uint8List bytes, String fileName, String mime) {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body?.append(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
  }

  static void downloadText(String text, String fileName, String mime) =>
      downloadBytes(Uint8List.fromList(utf8.encode(text)), fileName, mime);

  /// Opens a printable HTML document in a new tab and triggers print.
  static void printHtml(String html) {
    final withPrint = html.replaceFirst('</body>', '<script>window.onload=()=>setTimeout(()=>window.print(),300)</script></body>');
    final blob = web.Blob([withPrint.toJS].toJS, web.BlobPropertyBag(type: 'text/html'));
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
  }

  static void openUrl(String url) => web.window.open(url, '_blank');

  static String get origin => web.window.location.origin;

  static void setTitle(String t) => web.document.title = t;
}
