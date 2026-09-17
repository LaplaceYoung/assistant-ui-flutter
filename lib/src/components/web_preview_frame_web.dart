import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// A sandboxed iframe, registered as a platform view for Flutter web.
///
/// The element enforces no isolation itself, so the sandbox attribute is the
/// caller's contract — the same one upstream's `WebPreview` documents.
Widget? webPreviewFrame({
  required String url,
  required String sandbox,
  Key? key,
}) {
  final String viewType = 'aui-web-preview-${url.hashCode}-${sandbox.hashCode}';
  final bool registered = _registered.add(viewType);
  if (registered) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final web.HTMLIFrameElement frame = web.HTMLIFrameElement()
        ..src = url
        ..setAttribute('sandbox', sandbox)
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return frame;
    });
  }
  return HtmlElementView(viewType: viewType, key: key);
}

final Set<String> _registered = <String>{};

/// Whether this platform can embed a frame at all.
bool get webPreviewSupported => true;
