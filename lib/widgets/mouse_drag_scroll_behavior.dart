import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Desktop-friendly scrolling: trackpad, mouse wheel, and click-and-drag.
class MouseDragScrollBehavior extends MaterialScrollBehavior {
  const MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
