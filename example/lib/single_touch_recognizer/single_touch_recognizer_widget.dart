import 'package:flutter/material.dart';

import 'single_touch_recognizer.dart';

class SingleTouchRecognizerWidget extends StatelessWidget {
  final Widget child;
  SingleTouchRecognizerWidget({this.child});

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        SingleTouchRecognizer: GestureRecognizerFactoryWithHandlers<SingleTouchRecognizer>(
          () => SingleTouchRecognizer(),
          (SingleTouchRecognizer instance) {},
        ),
      },
      child: child,
    );
  }
}