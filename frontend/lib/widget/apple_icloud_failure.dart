import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/remote_module.dart';

class AppleICloudFailureWidget extends StatelessWidget {

  final void Function() retryFunction;

  const AppleICloudFailureWidget({super.key, required this.retryFunction});

  @override
  Widget build(BuildContext context) {
    return Container(height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: Colors.redAccent,
        ),
        child: Padding(padding: const EdgeInsets.all(10), child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisSize:MainAxisSize.max,
                children: [
                  const Padding(padding: EdgeInsets.fromLTRB(0, 5, 0, 0), child: Image(width: 50, image: AssetImage('images/apple_icloud_icon.png'))),
                  const SizedBox.square(dimension: 10),
                  Text("${RemoteModuleProvider.apple.getDisplayName()} Account Failure", style: const TextStyle(fontSize: 16)),
                ]),
            Padding(padding: const EdgeInsets.all(10), child: Text("${RemoteModuleProvider.apple.getDisplayName()} account is either not setup or not signed-in. Setup or sign-in to ${RemoteModuleProvider.apple.getDisplayShortName()} on this phone to continue.", style: const TextStyle(fontSize: 16))),
            Padding(padding: const EdgeInsets.all(10), child: RichText(text: TextSpan(
                text: "Open app settings and navigate to ${RemoteModuleProvider.apple.getDisplayShortName()}",
                style: const TextStyle(fontSize: 16, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()..onTap = () { launchAppSettings(); }
            )),
            ),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.all(10), child: RichText(text: TextSpan(
              text: "then ",
              style: const TextStyle(fontSize: 16),
              children: [
                TextSpan(
                    text: "retry ${RemoteModuleProvider.apple.getDisplayShortName()} account",
                    style: const TextStyle( fontSize: 16, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      retryFunction();
                    }
                )
              ],
            )))
          ],
        ))
    );
  }
}