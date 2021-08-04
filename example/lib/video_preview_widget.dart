import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewWidget extends StatelessWidget {
  final VideoPlayerController videoController;
  final String imagePath;

  const VideoPreviewWidget({Key key, this.videoController, this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: (videoController == null)
          ? Image.file(File(imagePath))
          : Container(
              child: Center(child: VideoPlayer(videoController)),
            ),
    );
  }
}
