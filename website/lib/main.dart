import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const LeafyWebsiteApp());
}

class LeafyWebsiteApp extends StatelessWidget {

  const LeafyWebsiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leafy',
      theme: _getLightTheme(),
      darkTheme: _getDarkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => const LeafyHomePage(title: 'Leafy 🌿'),
      },
    );
  }
}

final ThemeData _lightTheme = ThemeData.light(useMaterial3: true);

final ThemeData _darkTheme = ThemeData.dark(useMaterial3: true);

ThemeData _getLightTheme() {
  return _lightTheme.copyWith(textTheme: GoogleFonts.outfitTextTheme(_lightTheme.textTheme));
}

ThemeData _getDarkTheme() {
  return _darkTheme.copyWith(textTheme: GoogleFonts.outfitTextTheme(_darkTheme.textTheme));
}

class LeafyHomePage extends StatelessWidget {

  const LeafyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    TextStyle descriptionStyle = const TextStyle(fontSize: 40);
    const Duration textAnimationDuration = Duration(milliseconds: 150);
    double dividerHeight = 48;
    double documentationPaddingTop = 24;
    double documentationPaddingBottom = 20;
    double buttonHeight = 75;
    double appleAppStoreImageHeight = 40;
    double descriptionTextSize = 16;
    if (_getEffectiveDeviceType(context) == _EffectiveDeviceType.mobile) {
      dividerHeight = 12;
      documentationPaddingTop = 0;
      documentationPaddingBottom = 0;
      buttonHeight = 60;
      appleAppStoreImageHeight = 30;
      descriptionStyle = const TextStyle(fontSize: 32);
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
        actions: const [],
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child:
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child:
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.center, child: SizedBox(width: 800, child:
                  Padding(padding: const EdgeInsets.fromLTRB(10, 0, 0, 0), child:Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: Text("Leafy is ", style: descriptionStyle, textAlign: TextAlign.left)),
                      AnimatedTextKit(
                        repeatForever: true,
                        animatedTexts: [
                          TyperAnimatedText("Bitcoin that's easy to use.", textStyle: descriptionStyle, speed: textAnimationDuration),
                          TyperAnimatedText("for everyone.", textStyle: descriptionStyle, speed: textAnimationDuration),
                          TyperAnimatedText("secure.", textStyle: descriptionStyle, speed: textAnimationDuration),
                          TyperAnimatedText("self custodial.", textStyle: descriptionStyle, speed: textAnimationDuration),
                        ],
                      )
                    ]
                  )
                ))),
                SizedBox(height: dividerHeight),
                Align(alignment: Alignment.center, child:
                  Padding(padding: const EdgeInsets.fromLTRB(0, 0, 20, 0), child:
                    SizedBox(width: 800, child:
                      RichText(textAlign: TextAlign.center, text: TextSpan(
                        text: "Leafy is a Bitcoin wallet designed to be user-friendly. It is built for those who want to participate in Bitcoin via ",
                        style: TextStyle(fontSize: descriptionTextSize, fontWeight: FontWeight.w200, color: Theme.of(context).textTheme.bodyMedium!.color),
                        children: [
                          TextSpan(text: "self-custody", style: TextStyle(fontSize: descriptionTextSize, fontWeight: FontWeight.w200, decoration: TextDecoration.underline, color: Theme.of(context).textTheme.bodyMedium!.color),
                              recognizer: TapGestureRecognizer()..onTap = () { _launchSelfCustodyDocumentation(); }
                          ),
                          TextSpan(text: " but do not want to undertake the learning curve, cost and hassle required by other solutions.", style: TextStyle(fontSize: descriptionTextSize, fontWeight: FontWeight.w200, color: Theme.of(context).textTheme.bodyMedium!.color)),
                        ]
                      )),
                    ),
                  ),
                ),
                SizedBox(height: dividerHeight),
                Center(
                    child:
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(child: SizedBox(height: buttonHeight, child: IconButton(
                          icon: Image.asset('images/apple-app-store-badge.png', height: appleAppStoreImageHeight),
                          onPressed: () {
                            _launchAppleAppStore();
                          },
                        ))),
                        Center(child: SizedBox(height: buttonHeight, child: IconButton(
                          icon: Image.asset('images/google-play-badge.png'),
                          onPressed: () {
                            _launchGooglePlayStore();
                          },
                        ))),
                        const SizedBox(width: 50),
                      ],
                    )
                ),
              ],
            )),
            ),
            Expanded(flex: 1, child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(padding: EdgeInsets.fromLTRB(0, documentationPaddingTop, 20, documentationPaddingBottom),
                  child: InkWell(
                    onTap: () => {
                      _launchDocumentation()
                    },
                    child: const Text('Who should use Leafy?  |  Documentation',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.fromLTRB(0, documentationPaddingTop, 50, documentationPaddingBottom),
                  child: InkWell(
                    onTap: () => {
                      _launchPrivacyPolicy()
                    },
                    child: const Text('Privacy Policy',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                )
              ],
            )),
          ],
        ),
      ),
    );
  }
}

enum _EffectiveDeviceType {
  mobile,
  tablet,
  desktop
}

_EffectiveDeviceType _getEffectiveDeviceType(BuildContext context) {
  Size size = MediaQuery.of(context).size;
  double dimension = size.width > size.height ? size.height : size.width;
  if (size.width > 900) {
    return _EffectiveDeviceType.desktop;
  } else if (dimension > 600) {
    return _EffectiveDeviceType.tablet;
  } else {
    return _EffectiveDeviceType.mobile;
  }
}

final Uri _documentationUri = Uri.parse('https://github.com/blangel/leafy/blob/main/README.md');
final Uri _documentationSelfCustodyUri = Uri.parse('https://github.com/blangel/leafy/blob/main/README.md#self-custody');
final Uri _localPrivacyPolicyUri = Uri.parse("./docs/privacy_policy.html");
final Uri _privacyPolicyUri = Uri.parse("https://leafybitcoin.com/privacy_policy.html");
final Uri _googlePlayStoreUri = Uri.parse('https://leafybitcoin.com'); // TODO
final Uri _appleAppStoreUri = Uri.parse('https://leafybitcoin.com'); // TODO

Future<void> _launchDocumentation() async {
  _launchUri(_documentationUri);
}

Future<void> _launchSelfCustodyDocumentation() async {
  _launchUri(_documentationSelfCustodyUri);
}

Future<void> _launchPrivacyPolicy() async {
  _launchUri(kDebugMode ? _localPrivacyPolicyUri : _privacyPolicyUri);
}

Future<void> _launchGooglePlayStore() async {
  _launchUri(_googlePlayStoreUri);
}

Future<void> _launchAppleAppStore() async {
  _launchUri(_appleAppStoreUri);
}

Future<void> _launchUri(Uri uri) async {
  if (!await launchUrl(uri)) {
    throw Exception('Could not launch $uri');
  }
}
