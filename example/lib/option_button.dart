import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'enums/enum.dart';

//add icon animation code for screen rotation
class OptionButton extends StatefulWidget {
  final SvgPicture icon;
  final Function onTapCallback;
  final AnimationController rotationController;
  final ValueNotifier<CameraOrientations> orientation;
  final bool isEnabled;
  const OptionButton({
    Key key,
    this.icon,
    this.onTapCallback,
    this.rotationController,
    this.orientation,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  _OptionButtonState createState() => _OptionButtonState();
}

class _OptionButtonState extends State<OptionButton>
    with SingleTickerProviderStateMixin {
  double _angle = 0.0;
  CameraOrientations _oldOrientation = CameraOrientations.PORTRAIT_UP;

  @override
  void initState() {
    super.initState();

    /*Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.ease))
        .animate(widget.rotationController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _oldOrientation =
                  OrientationUtils.convertRadianToOrientation(_angle);
            }
          });

    widget.orientation.addListener(() {
      _angle =
          OrientationUtils.convertOrientationToRadian(widget.orientation.value);

      if (widget.orientation.value == CameraOrientations.PORTRAIT_UP) {
        widget.rotationController.reverse();
      } else if (_oldOrientation == CameraOrientations.LANDSCAPE_LEFT ||
          _oldOrientation == CameraOrientations.LANDSCAPE_RIGHT) {
        widget.rotationController.reset();

        if ((widget.orientation.value == CameraOrientations.LANDSCAPE_LEFT ||
            widget.orientation.value == CameraOrientations.LANDSCAPE_RIGHT)) {
          widget.rotationController.forward();
        } else if ((widget.orientation.value ==
            CameraOrientations.PORTRAIT_DOWN)) {
          if (_oldOrientation == CameraOrientations.LANDSCAPE_RIGHT) {
            widget.rotationController.forward(from: 0.5);
          } else {
            widget.rotationController.reverse(from: 0.5);
          }
        }
      } else if (widget.orientation.value == CameraOrientations.PORTRAIT_DOWN) {
        widget.rotationController.reverse(from: 0.5);
      } else {
        widget.rotationController.forward();
      }
    });*/
  }

  @override
  Widget build(BuildContext context) {
    /*return AnimatedBuilder(
      animation: widget.rotationController,
      builder: (context, child) {
        double newAngle;

        if (_oldOrientation == CameraOrientations.LANDSCAPE_LEFT) {
          if (widget.orientation.value == CameraOrientations.PORTRAIT_UP) {
            newAngle = -widget.rotationController.value;
          }
        }

        if (_oldOrientation == CameraOrientations.LANDSCAPE_RIGHT) {
          if (widget.orientation.value == CameraOrientations.PORTRAIT_UP) {
            newAngle = widget.rotationController.value;
          }
        }

        if (_oldOrientation == CameraOrientations.PORTRAIT_DOWN) {
          if (widget.orientation.value == CameraOrientations.PORTRAIT_UP) {
            newAngle = widget.rotationController.value * -pi;
          }
        }*/

    return IgnorePointer(
        ignoring: !widget.isEnabled,
        child: Opacity(
            opacity: widget.isEnabled ? 1.0 : 0.3,
            child: InkWell(
              child: widget.icon,
              onTap: () {
                if (widget.onTapCallback != null) {
                  // Trigger short vibration
                  HapticFeedback.selectionClick();

                  widget.onTapCallback();
                }
              },
            )));
  }
}
