import 'package:flutter/material.dart';

/// Non-web platforms have no iframe surface: the host supplies the frame, so
/// this returns null and the caller renders its own child.
Widget? webPreviewFrame({
  required String url,
  required String sandbox,
  Key? key,
}) =>
    null;

/// Whether this platform can embed a frame at all.
bool get webPreviewSupported => false;
