import 'package:web/web.dart' as web;

/// Opens a link in a new tab.
void openUrl(String url) {
  web.window.open(url, '_blank');
}
