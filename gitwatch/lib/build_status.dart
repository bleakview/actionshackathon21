import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BuildStatus extends StatefulWidget {
  final String statusImage;
  final String statusText;
  const BuildStatus(this.statusImage, this.statusText, {Key? key})
      : super(key: key);

  @override
  _BuildStatusState createState() => _BuildStatusState();
}

class _BuildStatusState extends State<BuildStatus> {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SvgPicture.asset(
        widget.statusImage,
        fit: BoxFit.fitWidth,
      ),
      Text(
        widget.statusText,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
    ]);
  }
}
