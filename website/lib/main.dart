import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
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
    const Duration textAnimationDuration = Duration(milliseconds: 100);
    double dividerHeight = 48;
    double documentationPaddingTop = 24;
    double documentationPaddingBottom = 20;
    double buttonHeight = 75;
    double appleAppStoreImageHeight = 40;
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
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text("Leafy is Bitcoin ", style: descriptionStyle),
                ),
                Center(
                  child: AnimatedTextKit(
                    repeatForever: true,
                    animatedTexts: [
                      TyperAnimatedText("that's easy to use", textStyle: descriptionStyle, speed: textAnimationDuration),
                      TyperAnimatedText("for everyone", textStyle: descriptionStyle, speed: textAnimationDuration),
                      TyperAnimatedText("that's secure", textStyle: descriptionStyle, speed: textAnimationDuration),
                      TyperAnimatedText("that's self custodial", textStyle: descriptionStyle, speed: textAnimationDuration),
                    ],
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
            )
            ),
            Expanded(flex: 1, child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(padding: EdgeInsets.fromLTRB(0, documentationPaddingTop, 50, documentationPaddingBottom),
                  child: InkWell(
                    onTap: () => {
                      _launchDocumentation()
                    },
                    child: const Text('Who should use Leafy?  |  Documentation',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
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
final Uri _googlePlayStoreUri = Uri.parse('http://leafybitcoin.com'); // TODO
final Uri _appleAppStoreUri = Uri.parse('http://leafybitcoin.com'); // TODO

Future<void> _launchDocumentation() async {
  _launchUri(_documentationUri);
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
