import 'dart:async';
import 'dart:io';
import 'package:flutter_better_camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import './camera_home.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    if (Platform.isIOS) {
      WidgetsFlutterBinding.ensureInitialized();
      // You can request multiple permissions at once.
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();
      print(statuses[Permission.camera]);
      print(statuses[Permission.microphone]);
    }
    cameras = await availableCameras();
    
  } on CameraException catch (e) {
    //logError(e.code, e.description);
  }
  runApp(CameraApp());
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraHome(
        cameras: cameras,
      ),
    );
  }
}
