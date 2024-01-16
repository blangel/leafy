import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:leafy/address.dart';
import 'package:leafy/addresses_list.dart';
import 'package:leafy/create_transaction.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/receive_address.dart';
import 'package:leafy/setup_new.dart';
import 'package:leafy/social_recovery.dart';
import 'package:leafy/start_branch.dart';
import 'package:leafy/transaction.dart';
import 'package:leafy/transactions_list.dart';
import 'package:leafy/wallet.dart';

void main() {
  runApp(const LeafyApp());
}

class LeafyApp extends StatelessWidget {
  const LeafyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leafy',
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => const LeafyHomePage(title: 'Leafy 🌿'),
        '/start': (context) => const LeafyStartPage(),
        '/new': (context) => const LeafySetupNewPage(),
        '/social-recovery': (context) => const SocialRecoveryPage(),
        // TODO : /timelock-recovery
        '/addresses': (context) => const AddressesListPage(),
        '/address': (context) => const AddressPage(),
        '/transactions': (context) => const TransactionsListPage(),
        '/transaction': (context) => const TransactionPage(),
        '/receive-address': (context) => const ReceiveAddressPage(),
        '/create-transaction': (context) => const CreateTransactionPage(),
        '/wallet': (context) => const LeafyWalletPage(),
      },
    );
  }
}

class LeafyHomePage extends StatelessWidget {
  const LeafyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const TextStyle descriptionStyle = TextStyle(fontSize: 40);
    const Duration textAnimationDuration = Duration(milliseconds: 100);
    double dividerHeight = 48;
    double documentationPaddingTop = 24;
    if (getEffectiveDeviceType(context) == EffectiveDeviceType.mobile) {
      dividerHeight = 24;
      documentationPaddingTop = 0;
    }
    return buildHomeScaffold(context, title, Center(
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
              const Center(
                child: Text("Leafy is ", style: descriptionStyle),
              ),
              Center(
                child: AnimatedTextKit(
                  repeatForever: true,
                  animatedTexts: [
                    TyperAnimatedText("easy to use", textStyle: descriptionStyle, speed: textAnimationDuration),
                    TyperAnimatedText("for everyone", textStyle: descriptionStyle, speed: textAnimationDuration),
                    TyperAnimatedText("secure", textStyle: descriptionStyle, speed: textAnimationDuration),
                    TyperAnimatedText("self custody", textStyle: descriptionStyle, speed: textAnimationDuration),
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
                      TextButton(onPressed: () {
                        Navigator.pushNamed(context, '/start');
                      }, child: const Text("start", style: TextStyle(fontSize: 32))),
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
              Padding(padding: EdgeInsets.fromLTRB(0, documentationPaddingTop, 50, 20),
                child: InkWell(
                  onTap: () => {
                    launchDocumentation()
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
