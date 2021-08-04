import 'dart:io';
import 'package:camera_example/bottom_bar_widget.dart';
import 'package:camera_example/upload_video_view.dart';
import 'package:camera_example/video_preview_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_better_camera/camera.dart';
import './zoomable_widget.dart';
import './camera_preview_widget.dart';
import 'enums/enum.dart';
import './camera_record_button.dart';
import 'option_button.dart';
import 'dart:async';
import 'single_touch_recognizer/single_touch_recognizer_widget.dart';

class CameraHome extends StatefulWidget {
  final List<CameraDescription> cameras;

  CameraHome({this.cameras});

  @override
  _CameraHomeState createState() => _CameraHomeState();
}

class _CameraHomeState extends State<CameraHome> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CameraController controller;
  String imagePath;
  String videoPath;
  VideoPlayerController videoController;
  VoidCallback videoPlayerListener;
  bool enableAudio;
  FlashMode flashMode ;
  CameraDescription camera;
  CameraRecordingstate cameraRecordingstate;
  Timer timer;
  int seconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initalizeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        onNewCameraSelected(controller.description);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Container(
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                    child: SingleTouchRecognizerWidget(
                      child: ZoomableWidget(
                          child: CameraPreviewwidget(
                            controller: controller,
                          ),
                          onZoom: (zoom) {
                             if(zoom is double)
                              controller.zoom(zoom);
                          }),
                    )),
              ),
              //video preview
              videoController == null && imagePath == null
                  ? Container()
                  : GestureDetector(
                      onTap: () {
                        videoController.value.isPlaying
                            ? pauseVideoWhilePreviewing()
                            : playVideoWhilePreviewing();
                        //print("aaaa "+videoController.toString());
                        print("position ${videoController.value.position.inSeconds}");
                        print("duaration ${videoController.value.duration.inSeconds}");
                        if (videoController.value.position.inSeconds ==
                            videoController.value.duration.inSeconds) {
                          print("ooo video finished");
                          //playVideoWhilePreviewing();
                          _startVideoPlayer();
                        }
                      },
                      child: Center(
                        child: !videoController.value.isPlaying || videoController.value.position.inSeconds == videoController.value.duration.inSeconds
                            ? 
                             Stack(
                                children: [
                                  VideoPreviewWidget(
                                    imagePath: imagePath,
                                    videoController: videoController,
                                  ),
                                  Opacity(
                                      opacity: 0.5,
                                      child: Container(
                                        color: Colors.black,
                                      )),
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                        "assets/camera/pause_and_play_video.svg"),
                                  ),
                                  ),
                                ],
                              ):Padding(
                              padding: EdgeInsets.all(0.0),
                              child: VideoPreviewWidget(
                                  imagePath: imagePath,
                                  videoController: videoController,
                                ),
                            ),
                      ),
                    ),
              //
               cameraRecordingstate == CameraRecordingstate.Finish ?
              //bottom bar after recording
              BottomBarWidget(
                leftImagePath: "assets/camera/delete_camera.svg",
                onTapLeftImage: cameraRecordingstate == CameraRecordingstate.Finish
                    ? initalizeCamera
                    : null,
                isDisabledRightButton: false, 
                rightImagePath: "assets/camera/valider_camera.svg",
                onTapRightImage: navigateToUploadVideoView // valider video et passer a l'interface de l'upload
              ):(cameraRecordingstate == CameraRecordingstate.RedRecording || cameraRecordingstate == CameraRecordingstate.GreenRecording?
              //bottom bar when recording
              BottomBarWidget(
                leftImagePath: "assets/camera/delete_camera.svg",
                onTapLeftImage: controller != null &&
                        controller.value.isInitialized &&
                        controller.value.isRecordingVideo
                    ? initalizeCamera
                    : null,
                isDisabledRightButton: cameraRecordingstate == CameraRecordingstate.GreenRecording ? false : true, // this value is related to video recording duration
                rightImagePath: "assets/camera/stop_camera.svg",
                onTapRightImage: controller != null &&
                        controller.value.isInitialized &&
                        controller.value.isRecordingVideo
                    ? onStopButtonPressed
                    : null,
              ):
              //bottom bar before recording
              Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
            opacity: 0.5,
            child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Color(0xff000000),
                ),
            ),
          ),
              )
              ),              
              //record button
              !controller.value.isRecordingVideo && cameraRecordingstate != CameraRecordingstate.Init ?
              Container():
              Padding(
                padding: const EdgeInsets.only(bottom: 25.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: CameraRecordButton(
                    cameraRecordingstate: cameraRecordingstate,
                    onTap: controller != null &&
                            controller.value.isInitialized &&
                            !controller.value.isRecordingVideo
                        ? onVideoRecordButtonPressed
                        : null,
                    colorCountDownContainer: cameraRecordingstate == CameraRecordingstate.Init
                      ? Colors.white
                      : (cameraRecordingstate == CameraRecordingstate.RedRecording
                          ? Colors.red
                          : Colors.green),
                  ),
                ),
              ),
              //
              //switch flash
              !controller.value.isRecordingVideo && cameraRecordingstate == CameraRecordingstate.Finish ?
              Container()
              : Padding(
                padding: EdgeInsets.only(bottom: 180, right: 27.0),
                child: Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  child: OptionButton(
                    //rotationController: _iconsAnimationController,
                    icon: _getFlashIcon(flashMode),
                    //orientation: _orientation,
                    onTapCallback:
                        controller != null && controller.value.isInitialized
                            ? onFlashButtonPressed
                            : null,
                  ),
                ),
              ),
              //
              //switch camera
              !controller.value.isRecordingVideo && cameraRecordingstate == CameraRecordingstate.Finish ?
              Container()
              :Padding(
                padding: EdgeInsets.only(bottom: 110, right: 17.0),
                child: Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  child: OptionButton(
                      icon: SvgPicture.asset("assets/camera/switch_camera.svg"),
                      //rotationController: _iconsAnimationController,
                      //orientation: _orientation,
                      onTapCallback: () {
                        switch (camera.lensDirection) {
                          case CameraLensDirection.front:
                            {
                              controller != null &&
                                      controller.value.isRecordingVideo
                                  ? null
                                  : () {
                                      camera = CameraDescription(
                                          name: "0",
                                          lensDirection:
                                              CameraLensDirection.back,
                                          sensorOrientation: 90);
                                      onNewCameraSelected(camera);
                                    }();
                            }
                            break;
                          case CameraLensDirection.back:
                            {
                              controller != null &&
                                      controller.value.isRecordingVideo
                                  ? null
                                  : () {
                                      camera = CameraDescription(
                                          name: "1",
                                          lensDirection:
                                              CameraLensDirection.front,
                                          sensorOrientation: 270);
                                      onNewCameraSelected(camera);
                                    }();
                            }
                            break;
                          default:
                            () {
                              camera = CameraDescription(
                                  name: "0",
                                  lensDirection: CameraLensDirection.back,
                                  sensorOrientation: 90);
                              onNewCameraSelected(camera);
                            }();
                        }
                      }),
                ),
              ),
              //
              
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
     //videoController.dispose();
    if(timer != null) timer.cancel();
    super.dispose();
  }

  /// Toggle Flash
  Future<void> onFlashButtonPressed() async {
    if (flashMode == FlashMode.off ) {
      // Turn on the flash for capture
      flashMode = FlashMode.torch;
    } else if (flashMode == FlashMode.torch) {
      // Turn on the flash for capture if needed
      flashMode = FlashMode.autoFlash;
    } else {
      // Turn off the flash
      flashMode = FlashMode.off;
    }
    // Apply the new mode
    await controller.setFlashMode(flashMode);

    // Change UI State
    setState(() {});
  }

  void onPauseButtonPressed() {
    pauseVideoRecording().then((_) {
      if (mounted) setState(() {});
      //showInSnackBar('Video recording paused');
    });
  }

  void onResumeButtonPressed() {
    resumeVideoRecording().then((_) {
      if (mounted) setState(() {});
      //showInSnackBar('Video recording resumed');
    });
  }

  void onStopButtonPressed() {
    stopVideoRecording().then((_) {
      if (mounted) setState(() {});
      //showInSnackBar('Video recorded to: $videoPath');
    });
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
          videoController?.dispose();
          videoController = null;
        });
        if (filePath != null) showInSnackBar('Picture saved to $filePath');
      }
    });
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((String filePath) {
      if (mounted) setState(() {});
      if (filePath != null) {
        //showInSnackBar('Saving video to $filePath');
        print("ooo");
        cameraRecordingstate = CameraRecordingstate.RedRecording;
        // state of recording button => Recording
        //limit video to max 30 seconds
          startTimer();
          
      }
      ;
    });
  }
  
  
  void startTimer() {
    const oneSec = const Duration(seconds: 10);
     timer = Timer.periodic(
      oneSec,
      (Timer timer) => setState(() {
          seconds = seconds - oneSec.inSeconds;
          if(seconds == 20){
            //print("ooo change state camera recording state");
              cameraRecordingstate = CameraRecordingstate.GreenRecording;
            }
          if (seconds == 0) {
            //print("ooo change state camera recording state & cancel timer & stop camera");
            timer.cancel();
            stopVideoRecording();
            cameraRecordingstate = CameraRecordingstate.Finish;
          } 
        },
      ),
    );
  }

  Future<String> startVideoRecording() async {
    if (!controller.value.isInitialized) {
      //showInSnackBar('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.mp4';

    if (controller.value.isRecordingVideo) {
      // A recording is already started

      return null;
    }

    try {
      videoPath = filePath;
      await controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {

    if (!controller.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    //stop timer and change camera state recording
    timer.cancel();
    cameraRecordingstate = CameraRecordingstate.Finish;
    await _startVideoPlayer();
  }

  Future<void> pauseVideoRecording() async {
    if (!controller.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller.pauseVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller.resumeVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  ///start video player preview after recording the video
  Future<void> _startVideoPlayer() async {
    final VideoPlayerController vcontroller = VideoPlayerController.file(File(videoPath));

    videoPlayerListener = () {
      if (videoController != null && videoController.value.size != null) {
        // Refreshing the state to update video player with the correct ratio.
        if (mounted) setState(() {});
        videoController.removeListener(videoPlayerListener);
      }
    };
    vcontroller.addListener(videoPlayerListener);
    await vcontroller.setLooping(false);
    await vcontroller.initialize();
    //await videoController?.dispose(); //dispose later when navigating
    if (mounted) {
      setState(() {
        imagePath = null;
        videoController = vcontroller;
      });
    }
    
    await vcontroller.play();

  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      //showInSnackBar('Error: select a camera first.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void pauseVideoWhilePreviewing()async {
   await  videoController.pause();
    setState(() {});
  }

  void playVideoWhilePreviewing()async {
    await videoController.play();
    setState(() {});
  }

 

  void toogleAutoFocus() {
    controller.setAutoFocus(!controller.value.autoFocusEnabled);
    showInSnackBar('Toogle auto focus');
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: enableAudio,
    );

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  ///initialize the camera with back camera
  void initalizeCamera() {
    seconds = 30;
    flashMode = FlashMode.off;
    cameraRecordingstate = CameraRecordingstate.Init;
    if(timer!= null) timer.cancel();
    if(videoController != null){
      videoController = null;
      imagePath = null;
    }
    
    camera = CameraDescription(
        name: "0",
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90);
    enableAudio = true;
    controller = CameraController(camera, ResolutionPreset.medium);
    controller != null && controller.value.isRecordingVideo
        ? null
        : onNewCameraSelected(camera);
  }

  void navigateToUploadVideoView(){
    Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => UploadVideoView()),
  );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void logError(String code, String message) =>
      print('Error: $code\nError Message: $message');
}

SvgPicture _getFlashIcon(FlashMode flashMode) {
  switch (flashMode) {
    case FlashMode.off:
      return SvgPicture.asset("assets/camera/flash_camera_off.svg");
    case FlashMode.torch:
      return SvgPicture.asset("assets/camera/flash_camera_on.svg");
    case FlashMode.autoFlash:
      return SvgPicture.asset("assets/camera/flash_camera_auto.svg");
    default:
      return SvgPicture.asset("assets/camera/flash_camera_off.svg");
  }
}

