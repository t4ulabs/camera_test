import 'package:flutter/material.dart';
import 'package:flutter_better_camera/camera.dart';

class CameraPreviewwidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewwidget({Key key, @required this.controller})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return controller == null || !controller.value.isInitialized
        ? Container()
        : AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          );
  }
}
