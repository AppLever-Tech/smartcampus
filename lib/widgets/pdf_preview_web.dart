// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final Set<String> _registeredPdfViews = <String>{};

Widget buildPdfPreview(String url, {double height = 480}) {
  final String viewType = 'pdf-preview-${url.hashCode}';

  if (!_registeredPdfViews.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final html.IFrameElement iframe = html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..width = '100%'
          ..height = '100%';
        return iframe;
      },
    );
    _registeredPdfViews.add(viewType);
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: HtmlElementView(viewType: viewType),
    ),
  );
}
