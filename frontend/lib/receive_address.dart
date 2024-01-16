
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/widget/address.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

class ReceiveAddressPage extends StatefulWidget {

  const ReceiveAddressPage({super.key});

  @override
  State<ReceiveAddressPage> createState() => _ReceiveAddressState();

}

class _ReceiveAddressState extends State<ReceiveAddressPage> {

  final AssetImage _qrScanImage = const AssetImage('images/qr_scan.gif');

  late double originalBrightness;

  @override
  void initState() {
    super.initState();
    _getOriginalBrightness();
    _setBrightness(1.0);
  }

  @override
  void dispose() {
    _setBrightness(originalBrightness);
    super.dispose();
  }

  void _getOriginalBrightness() async {
    originalBrightness = await ScreenBrightness().current;
  }

  void _setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as AddressArgument;
    return buildScaffold(context, "Receive Bitcoin",
        Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image(height: 100, image: _qrScanImage, alignment: Alignment.centerLeft),
                const Padding(padding: EdgeInsets.all(10), child: Text("Your Bitcoin address", style: TextStyle(fontSize: 24))),
              ],
            ),
            Center(
              child: Padding(padding: const EdgeInsets.all(20), child:
              Container(
                  color: Colors.white,
                  child: QrImageView(
                    data: arguments.address,
                    version: QrVersions.auto,
                    size: 200.0,
                  )
              ),
              ),
            ),
            CopyableDataWidget(data: arguments.address),
            Padding(padding: const EdgeInsets.all(10), child: RichText(text: TextSpan(
                text: "This is a Segwit v1 address, to learn more about how Leafy wallets work, ",
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                children: [
                  TextSpan(text: "see the documentation", style: TextStyle(fontSize: 12, decoration: TextDecoration.underline, color: Theme.of(context).textTheme.bodyMedium!.color),
                      recognizer: TapGestureRecognizer()..onTap = () { launchDocumentation(); }
                  ),
                ]
            )),
            )
          ],
        )
    );
  }
}