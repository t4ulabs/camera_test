import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class BottomBarWidget extends StatelessWidget {

  final String leftImagePath;
  final Function onTapLeftImage;
  final bool isDisabledRightButton;
  final String rightImagePath;
  final Function onTapRightImage;

  const BottomBarWidget(
      {Key key,
      @required this.leftImagePath,
      @required this.onTapLeftImage,
      @required this.rightImagePath,
      @required this.onTapRightImage,
      @required this.isDisabledRightButton})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      right: 0,
      child: Stack(
        children: [
          Opacity(
            opacity: 0.5,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Color(0xff000000),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(left: 30.0, right: 30.0, top: 13.0),
            child: 
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                          onTap: onTapLeftImage,
                          child: SvgPicture.asset(
                            leftImagePath,
                          )),
                      GestureDetector(
                        onTap: isDisabledRightButton ? null : onTapRightImage,
                        child: SvgPicture.asset(rightImagePath,
                            color: isDisabledRightButton
                                ? Colors.white.withOpacity(0.36)
                                : Colors.white),
                      ),
                    ],
                  )
                
          ),
        ],
      ),
    );
  }
}
