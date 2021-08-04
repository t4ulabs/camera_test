import 'package:flutter/gestures.dart';

class SingleTouchRecognizer extends OneSequenceGestureRecognizer {
  
    int _p = 0;
  @override
  void addAllowedPointer(PointerDownEvent event) {
    //first register the current pointer so that related events will be handled by this recognizer
    startTrackingPointer(event.pointer);
    //ignore event if another event is already in progress
    if (_p == 0) {
      print("=== "+event.pointer.toString());
      resolve(GestureDisposition.rejected);
    } else {
      _p = event.pointer;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  String get debugDescription => throw UnimplementedError();

  @override
  void didStopTrackingLastPointer(int pointer) {
    }
  
    @override
    void handleEvent(PointerEvent event) {
       if (!event.down && event.pointer == _p) {
      _p = 0;
    }
  }

  
}