import 'dart:developer';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/apple_icloud_remote_account.dart';
import 'package:leafy/util/google_drive_remote_account.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:leafy/util/wallet.dart';
import 'package:leafy/widget/apple_icloud_failure.dart';
import 'package:leafy/widget/wallet_password.dart';
import 'dart:io' show Platform;

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
  bool _backingUpViaGoogle = false;
  bool _backingUpViaApple = false;
  bool _appleICloudNotLoggedIn = false;
  late AnimationController _animationController;

  late final Wallet _wallet;

  late final GoogleSignInUtil _googleSignIn;

  late final AppleICloudRemoteAccount _appleICloud;
  
  late final RemoteModule _remoteAccount;
  bool _remoteAccountInitialized = false;

  bool _advancedTileExpanded = false;
  String? _password;

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
          if (!_remoteAccountInitialized) {
            _remoteAccount = await GoogleDriveRemoteAccount.create(account);
          }
          _remoteAccountInitialized = true;
          _setupRemote(account.email, RemoteModuleProvider.google);
        } else {
          if (mounted) {
            setState(() {
              _uiState = _UiState.readyForBackup;
            });
          }
        }
      } on Exception catch(e) {
        if (mounted) {
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
    _appleICloud = AppleICloudRemoteAccount.create();
  }

  Future<void> _setupRemote(String remoteAccountId, RemoteModuleProvider provider) async {
    globalRemoteAccountId = remoteAccountId;
    await persistRemotely(_wallet.firstMnemonic, _wallet.secondMnemonic);
    await persistLocally(_password, _wallet.firstMnemonic, _wallet.secondDescriptor, remoteAccountId, provider);
    if (mounted) {
      setAsNeedingCompanionDeviceBackup();
      Navigator.popAndPushNamed(context, '/wallet', arguments: KeyArguments(firstMnemonic: _wallet.firstMnemonic, secondMnemonic: _wallet.secondMnemonic, secondDescriptor: _wallet.secondDescriptor, walletPassword: _password, remoteProvider: provider));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildScaffold(context, 'New Wallet Setup', Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(child: Image(height: 150, image: _lockImage)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          child: RichText(text: TextSpan(
              text: "Let's finish creating your Bitcoin wallet. Your wallet is compromised of two keys. One key will be encrypted and then stored on your chosen ",
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
        Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                    child: Align(alignment: Alignment.centerLeft, child: RichText(text: TextSpan(text: "Select a ", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color), children: [
                      TextSpan(text: "Remote Account", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color, fontWeight: FontWeight.bold)),
                      TextSpan(text: " to continue:", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color)),
                    ])))
                ),
                if (Platform.isIOS)
                  ...[
                    Padding(padding: const EdgeInsets.all(10), child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: (_uiState == _UiState.backingUp || (_remoteAccountInitialized && _remoteAccount.getProvider() == RemoteModuleProvider.google)) ? null : () async {
                            setState(() {
                              _uiState = _UiState.backingUp;
                              _backingUpViaApple = true;
                              _backingUpViaGoogle = false;
                            });
                            if (!_remoteAccountInitialized) {
                              _remoteAccount = _appleICloud;
                            }
                            _remoteAccountInitialized = true;
                            if (!await _appleICloud.isLoggedIn()) {
                              setState(() {
                                _appleICloudNotLoggedIn = true;
                              });
                            } else {
                              String? userId = await _appleICloud.getUserId();
                              if (userId != null) {
                                _setupRemote(userId, RemoteModuleProvider.apple);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text("Could not load ${RemoteModuleProvider.apple.getDisplayShortName()} id for user", style: const TextStyle(color: Colors.white),),
                                    backgroundColor: Colors.redAccent,
                                  ));
                                }
                                setState(() {
                                  _appleICloudNotLoggedIn = true;
                                });
                              }
                            }
                          },
                          child: Center(child: Row(mainAxisSize:MainAxisSize.min,
                              children: [
                                const Padding(padding: EdgeInsets.fromLTRB(0, 5, 0, 0), child: Image(width: 50, image: AssetImage('images/apple_icloud_icon.png'))),
                                const SizedBox.square(dimension: 10),
                                Text(RemoteModuleProvider.apple.getDisplayName(), style: const TextStyle(fontSize: 24),),
                                if (_uiState == _UiState.backingUp && _backingUpViaApple)
                                  ...[const SizedBox.square(dimension: 10),
                                    Center(child: CircularProgressIndicator(value: _animationController.value)),]
                                else
                                  ...[]
                              ])),
                        )
                      ],
                    ))
                  ],
                Padding(padding: const EdgeInsets.all(10), child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: (_uiState == _UiState.backingUp || (_remoteAccountInitialized && _remoteAccount.getProvider() == RemoteModuleProvider.apple)) ? null : () async {
                        setState(() {
                          _uiState = _UiState.backingUp;
                          _backingUpViaApple = false;
                          _backingUpViaGoogle = true;
                        });
                        await _googleSignIn.signIn();
                      },
                      child: Row(mainAxisSize:MainAxisSize.min,
                          children: [
                            const Image(width: 50, image: AssetImage('images/google_drive_icon.png')),
                            const SizedBox.square(dimension: 10),
                            Text(RemoteModuleProvider.google.getDisplayName(), style: const TextStyle(fontSize: 24),),
                            if (_uiState == _UiState.backingUp && _backingUpViaGoogle)
                              ...[const SizedBox.square(dimension: 10),
                                Center(child: CircularProgressIndicator(value: _animationController.value)),]
                            else
                              ...[]
                          ]),
                    )
                  ],
                )),
              ]
            ),
            if (_appleICloudNotLoggedIn)
              ...[
                AppleICloudFailureWidget(retryFunction: () {
                  setState(() {
                    _uiState = _UiState.readyForBackup;
                    _backingUpViaApple = false;
                    _backingUpViaGoogle = false;
                    _appleICloudNotLoggedIn = false;
                  });
                })
              ]
          ]
        ),
        Expanded(flex: 1, child: Align(alignment: Alignment.bottomLeft,
          child: SingleChildScrollView(child: ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                if (_password == null) {
                  _advancedTileExpanded = !_advancedTileExpanded;
                }
              });
            },
            expandedHeaderPadding: EdgeInsets.zero,
            children: [
              ExpansionPanel(headerBuilder: (BuildContext context, bool isExpanded) {
                return const ListTile(
                  title: Text("Advanced settings"),
                );
              },
              canTapOnHeader: true,
              body: ListTile(
                title: _password != null ? const Text("Wallet protected with a password") : const Text("Protect wallet with a password"),
                subtitle: _password != null ? const Text("Tap to remove", style: TextStyle(color: Colors.redAccent),) : const Text('Warning! There is no "forgot password" functionality.'),
                trailing: _password != null ? const Icon(Icons.delete) : const Icon(Icons.password),
                onTap: () {
                  if (_password != null) {
                    setState(() {
                      _password = null;
                    });
                    return;
                  }
                  showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => const WalletPasswordDialog(),
                  ).then((password) {
                    setState(() {
                      _password = password;
                    });
                  });
                }
              ),
              isExpanded: _advancedTileExpanded || (_password != null),
              )
            ],
          )),
        )),
        const SizedBox(height: 40)
      ],
    ));
  }

  Future<void> persistRemotely(String firstMnemonic, String secondMnemonic) async {
    final secondMnemonicEncrypted = encryptLeafyData(firstMnemonic, secondMnemonic);
    final validator = DefaultSecondSeedValidator.create(firstMnemonic, secondMnemonic);
    final valid = await _remoteAccount.persistEncryptedSecondSeed(secondMnemonicEncrypted, validator);
    if (!valid) {
      throw Exception("Second mnemonic backup failure, please retry");
    }
  }

}