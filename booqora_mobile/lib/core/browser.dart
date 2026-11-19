import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mobile counterpart of the web `Browser` helper: opens links and shares files.
class Browser {
  /// Public web origin (storefront links, embed snippets, payment returns).
  static const origin = 'https://booqora-platform.web.app';

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    final external = uri.scheme == 'mailto' || uri.scheme == 'tel' || uri.scheme == 'sms' || uri.scheme == 'https' && !url.startsWith(origin);
    await launchUrl(uri, mode: external ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView);
  }

  /// Shares bytes as a file (CSV exports, PDFs, .ics) through the system share sheet.
  static Future<void> downloadBytes(Uint8List bytes, String fileName, String mime) =>
      SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: fileName, mimeType: mime)], fileNameOverrides: [fileName]));

  static Future<void> downloadText(String text, String fileName, String mime) =>
      downloadBytes(Uint8List.fromList(utf8.encode(text)), fileName, mime);

  static Future<void> shareText(String text, {String? subject}) => SharePlus.instance.share(ShareParams(text: text, subject: subject));

  static void setTitle(String _) {}
}
