import 'package:camera_example/enums/enum.dart';
import 'package:fdottedline/fdottedline.dart';
import 'package:flutter/material.dart';

import 'count_down_dashed_circle/time_circular_countdown.dart';

class CameraRecordButton extends StatelessWidget {
  final CameraRecordingstate cameraRecordingstate;
  final Color colorCountDownContainer;
  final Function onTap;

  const CameraRecordButton(
      {Key key,
      this.colorCountDownContainer,
      this.onTap,
      this.cameraRecordingstate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return cameraRecordingstate == CameraRecordingstate.Init ?
    GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          whiteCirecle(),
          plainCircle(colorCountDownContainer)
        ],
      ),
    ):
    GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          plainCircle(colorCountDownContainer),
          dashedCircle(cameraRecordingstate),
        ],
      ),
    );
  }
}

Widget whiteCirecle() {
  return Positioned(
    bottom: 0,
    right: 10,
    left: 10,
    child: Padding(
      padding: EdgeInsets.only(right: 160, left: 160),
      child: FDottedLine(
        color: Colors.white,
        height: 72.0,
        width: 72.0,
        space: 0,
        strokeWidth: 2,

        /// Set corner
        corner: FDottedLineCorner.all(50),
      ),
    ),
  );
}

Widget dashedCircle(CameraRecordingstate cameraRecordingstate){
  return Positioned(
            bottom: 0,
            right: 10,
            left: 10,
            child: TimeCircularCountdown(
              unit: CountdownUnit.second,
              countdownCurrentColor: Colors.white,
              countdownRemainingColor: Colors.white,
              countdownTotal: 30,
              countdownTotalColor: cameraRecordingstate == CameraRecordingstate.RedRecording ? Colors.red : Colors.green,
              diameter: 74.0,
              gapFactor: 2.0,
              isClockwise: true,
              repeat: true,
              strokeWidth: 3.0,
              textStyle: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.normal,
              ),
            ),
          );
}

Widget plainCircle(Color colorCountDownContainer){
  return Padding(
            padding: const EdgeInsets.all(9.0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                    border: Border.all(color: colorCountDownContainer),
                    shape: BoxShape.circle,
                    color: colorCountDownContainer),
              ),
            ),
          );
}