import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:flutter/gestures.dart';
import 'package:leafy/util/google_drive_remote_account.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:leafy/util/wallet.dart';

class LeafySetupNewPage extends StatefulWidget {
  const LeafySetupNewPage({super.key});

  @override
  State<LeafySetupNewPage> createState() => _LeafySetupNewState();
}

enum _UiState {
  generatingMnemonic, readyForBackup, backingUp
}

class _LeafySetupNewState extends State<LeafySetupNewPage> with TickerProviderStateMixin {

  final AssetImage _lockImage = const AssetImage('images/key_creation.gif');

  _UiState _uiState = _UiState.generatingMnemonic;
  late AnimationController _animationController;

  late final Wallet _wallet;

  late final GoogleSignInUtil _googleSignIn;
  
  late final RemoteModule _remoteAccount;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(() {
      setState(() {});
    });
    _animationController.repeat();
    super.initState();

    createNewWallet().then((wallet) {
      setState(() {
        _wallet = wallet;
        _uiState = _UiState.readyForBackup;
      });
    });
    _googleSignIn = GoogleSignInUtil.create((account) async {
      try {
        if (account != null) {
          _remoteAccount = await GoogleDriveRemoteAccount.create(account!);
          await persistLocally(_wallet.firstMnemonic, _wallet.secondDescriptor, account.email);
          await persistRemotely(_wallet.firstMnemonic, _wallet.secondMnemonic);
          if (context.mounted) {
            Navigator.popAndPushNamed(context, '/wallet', arguments: KeyArguments(firstMnemonic: _wallet.firstMnemonic, secondMnemonic: _wallet.secondMnemonic, secondDescriptor: _wallet.secondDescriptor));
          }
        } else {
          if (context.mounted) {
            setState(() {
              _uiState = _UiState.readyForBackup;
            });
          }
        }
      } on Exception catch(e) {
        if (context.mounted) {
          setState(() {
            _uiState = _UiState.readyForBackup;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString(), style: const TextStyle(color: Colors.white),),
            backgroundColor: Colors.redAccent,
          ));
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildScaffold(context, 'New Wallet Setup', Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(child: Image(height: 150, image: _lockImage)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          child: RichText(text: TextSpan(
              text: "Let's finish creating your Bitcoin wallet. The online portion of your wallet will be encrypted before being stored on your ",
              style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color),
              children: [
                TextSpan(text: "Remote Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium!.color)),
                TextSpan(text: "\n\nFor more information about how Leafy wallets work, ", style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium!.color)),
                TextSpan(text: "see the documentation", style: TextStyle(fontSize: 16, decoration: TextDecoration.underline, color: Theme.of(context).textTheme.bodyMedium!.color),
                    recognizer: TapGestureRecognizer()..onTap = () { launchDocumentation(); }
                ),
                TextSpan(text: ".", style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium!.color)),
              ]
          )),
        ),
        Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 10, endIndent: 10),
        Padding(padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
          child: Align(alignment: Alignment.centerLeft, child: RichText(text: TextSpan(text: "Select a ", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color), children: [
            TextSpan(text: "Remote Account", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color, fontWeight: FontWeight.bold)),
            TextSpan(text: " to continue:", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color)),
          ])))
        ),
        Padding(padding: const EdgeInsets.all(10), child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: (_uiState == _UiState.backingUp) ? null : () async {
                setState(() {
                  _uiState = _UiState.backingUp;
                });
                await _googleSignIn.signIn();
              },
              child: Row(mainAxisSize:MainAxisSize.min,
                  children: [
                    const Image(width: 50, image: AssetImage('images/google_drive_icon.png')),
                    const SizedBox.square(dimension: 10),
                    const Text("Google Drive", style: TextStyle(fontSize: 24),),
                    if (_uiState == _UiState.backingUp)
                      ...[const SizedBox.square(dimension: 10),
                        Center(child: CircularProgressIndicator(value: _animationController.value)),]
                    else
                      ...[]
                  ]),
            )
          ],
        ))
      ],
    ));
  }

  Future<void> persistLocally(String firstMnemonic, String secondDescriptor, String remoteAccountId) async {
    await persistLocallyViaBiometric(firstMnemonic, secondDescriptor, remoteAccountId);
  }

  Future<void> persistRemotely(String firstMnemonic, String secondMnemonic) async {
    final secondMnemonicEncrypted = encryptSecondSeed(firstMnemonic, secondMnemonic);
    final validator = DefaultSecondSeedValidator.create(firstMnemonic, secondMnemonic);
    final valid = await _remoteAccount.persistEncryptedSecondSeed(secondMnemonicEncrypted, validator);
    if (!valid) {
      throw Exception("Second mnemonic backup failure, please retry");
    }
  }

}