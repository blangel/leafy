import 'dart:io';

import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/apple_icloud_remote_account.dart';
import 'package:leafy/util/google_drive_remote_account.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:leafy/util/wallet.dart';
import 'package:leafy/widget/apple_icloud_failure.dart';
import 'package:leafy/widget/wallet_password.dart';

// Possible branches and their handling:
// (0) [normal] locally have first-mnemonic, second-descriptor and second-mnemonic via remote-account => '/wallet'
// (1) [new | social] nothing locally and nothing on remote-account => ask for '/social-recovery', otherwise '/new'
// (2) [recovery] locally have first-mnemonic, second-descriptor but no remote-account access => '/timelock-recovery'
// (3) [social] nothing locally, and second-mnemonic via remote-account => '/social-recovery'

// LeafyStartPage determines if a user has an existing account, branching
// to the proper page depending upon existence

class LeafyStartPage extends StatefulWidget {
  const LeafyStartPage({super.key});

  @override
  State<LeafyStartPage> createState() => _LeafyStartState();
}

enum _UiState {
  loadingLocal, // initial state, loading local
  noLocal, // no local found, branch (1) or (3)
  noLocalTryingRemote, // no local found, branch (3), attempting social-recovery so need remote account
  noLocalFoundRemote, // no local found, branch (3), attempting social-recovery and found remote account
  localNeedDecrypting, // found local but needs to be decrypted
  localFailedDecryption, // found local and failed to decrypt it
  localDecryptedNeedRemote, // found local and decrypted, branch (0) or (2), attempting remote account sign-in
}

class _LeafyStartState extends State<LeafyStartPage> with TickerProviderStateMixin {

  late AnimationController _animationController;

  late final RemoteModule _remoteAccount;
  late final GoogleSignInUtil _googleSignIn;
  late final AppleICloudRemoteAccount _appleICloud;
  bool _remoteAccountInitialized = false;
  bool _checkingRemoteViaGoogle = false;
  bool _checkingRemoteViaApple = false;
  bool _appleICloudNotLoggedIn = false;

  _UiState _uiState = _UiState.loadingLocal;
  RecoveryWallet? _recoveryWallet;
  String? _password;
  bool _retrievingPassword = false;

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
    getRecoveryWallet().then((wallet) {
      // no local; either (1) or (3)
      if (wallet == null) {
        setState(() {
          _uiState = _UiState.noLocal;
        });
      }
      // local; either (0) or (2)
      else {
        _recoveryWallet = wallet;
        var localState = _determineUiStateFromLocalWallet(wallet);
        setState(() {
          _uiState = localState;
        });
        if (localState == _UiState.localDecryptedNeedRemote) {
          _remoteAccountLoginAfterFindingLocal();
        }
      }
    });
    _googleSignIn = GoogleSignInUtil.create((account) async {
      try {
        if (!mounted) {
          return;
        }
        if (account != null) {
          if (!_remoteAccountInitialized) {
            _remoteAccount = await GoogleDriveRemoteAccount.create(account);
          }
          _remoteAccountInitialized = true;
          await _loadFromRemote(account.email);
        } else {
          _failedToLoadRemote("No ${RemoteModuleProvider.google.getDisplayShortName()} account found");
        }
      } on Exception catch(e) {
        _failedToLoadRemote(e.toString());
      }
    });
    _appleICloud = AppleICloudRemoteAccount.create();
  }

  void _failedToLoadRemote(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$message; loading wallet, please retry", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 7),
      ));
      Navigator.pop(context);
    }
  }

  Future<void> _attemptAppleICloud() async {
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
        await _loadFromRemote(userId);
      } else {
        _failedToLoadRemote("No ${RemoteModuleProvider.apple.getDisplayShortName()} account id found");
      }
    }
  }

  Future<void> _loadFromRemote(String remoteAccountId) async {
    globalRemoteAccountId = remoteAccountId;
    var encryptedContent = await _remoteAccount.getEncryptedSecondSeed();
    if (!mounted) {
      return;
    }
    if (_recoveryWallet == null) {
      Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.walletPassword, remoteAccountId: remoteAccountId, remoteProvider: _remoteAccount.getProvider(), walletPassword: null, walletFirstMnemonic: null));
      return;
    }
    if (encryptedContent != null) {
      final decrypted = decryptLeafyData(_recoveryWallet!.firstMnemonic, encryptedContent, mnemonicLength);
      if (decrypted != null) {
        Navigator.popAndPushNamed(context, '/wallet', arguments: KeyArguments(firstMnemonic: _recoveryWallet!.firstMnemonic, secondMnemonic: decrypted, secondDescriptor: _recoveryWallet!.secondDescriptor, walletPassword: _password, remoteProvider: _remoteAccount.getProvider(), ));
        return;
      } else {
        Navigator.popAndPushNamed(context, '/timelock-recovery', arguments: TimelockRecoveryArguments(walletPassword: _password, walletFirstMnemonic: _recoveryWallet!.firstMnemonic, walletSecondDescriptor: _recoveryWallet!.secondDescriptor));
        return;
      }
    } else {
      Navigator.popAndPushNamed(context, '/timelock-recovery', arguments: TimelockRecoveryArguments(walletPassword: _password, walletFirstMnemonic: _recoveryWallet!.firstMnemonic, walletSecondDescriptor: _recoveryWallet!.secondDescriptor));
      return;
    }
  }

  _UiState _determineUiStateFromLocalWallet(RecoveryWallet wallet) {
    if (firstSeedMnemonicNeedsPassword(wallet.firstMnemonic)) {
      return _UiState.localNeedDecrypting;
    }
    return _UiState.localDecryptedNeedRemote;
  }

  Future<void> _remoteAccountLoginAfterFindingLocal() async {
    if (_recoveryWallet == null) {
      return;
    }
    switch (_recoveryWallet!.remoteProvider) {
      case RemoteModuleProvider.google:
        _googleSignIn.signIn();
        break;
      case RemoteModuleProvider.apple:
        _attemptAppleICloud();
        break;
      default:
        throw Exception("programming error: unhandled provider type ${_recoveryWallet!.remoteProvider.name}");
    }
  }

  void _updatePasswordState(String? password) {
    if (_recoveryWallet == null) {
      return;
    }
    final decryptedWallet = (password == null ? null : decryptWallet(password, _recoveryWallet!));
    if (decryptedWallet == null) {
      setState(() {
        _password = null;
        _uiState = _UiState.localFailedDecryption;
      });
    } else {
      setState(() {
        _password = password;
        _recoveryWallet = decryptedWallet;
        _uiState = _UiState.localDecryptedNeedRemote;
        _remoteAccountLoginAfterFindingLocal();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // if _UiState is localNeedDecrypting, immediately ask for password
    if (!_retrievingPassword && _uiState == _UiState.localNeedDecrypting) {
      Future.microtask(() {
        _retrievingPassword = true;
        showDialog<String>(
          context: context,
          builder: (BuildContext context) =>
          const WalletPasswordDialog(newPassword: false),
        ).then((password) {
          _retrievingPassword = true;
          _updatePasswordState(password);
        });
      });
    }
    return buildScaffold(context, 'Wallet Check', Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_uiState == _UiState.loadingLocal
              || _uiState == _UiState.localNeedDecrypting)
            ...[
              const Center(child: Text('Checking for existing wallet...', style: TextStyle(fontSize: 24))),
              const SizedBox(height: 50),
              Center(child: CircularProgressIndicator(value: _animationController.value)),
              const SizedBox(height: 100),
            ]
          else if (_uiState == _UiState.noLocal)
            ...[
              const Align(alignment: Alignment.topRight, child: Text('No existing wallet found on this device', style: TextStyle(fontSize: 24))),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.topCenter,
                child:
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextButton(onPressed: () {
                        Navigator.popAndPushNamed(context, '/new');
                      }, child: const Text("create new", style: TextStyle(fontSize: 32))),
                      const SizedBox(width: 25),
                    ],
                  )
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.topCenter,
                child:
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("or attempt"),
                      TextButton(onPressed: () {
                        setState(() {
                          _uiState = _UiState.noLocalTryingRemote;
                        });
                      }, child: const Text("recovery", style: TextStyle(fontSize: 16))),
                      const Text("via a companion device"),
                      const SizedBox(width: 10),
                    ],
                  )
              ),
              const SizedBox(height: 100),
            ]
          else if (_uiState == _UiState.noLocalTryingRemote || _uiState == _UiState.noLocalFoundRemote)
            ...[
              Stack(
                children: [
                  Column(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child:
                          RichText(text: TextSpan(text: "To start wallet recovery, select your existing ",
                              style: TextStyle(fontSize: 22, color: Theme.of(context).textTheme.bodyMedium!.color),
                              children: [
                                TextSpan(text: "Remote Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium!.color)),
                                TextSpan(text: ".", style: TextStyle(fontSize: 22, color: Theme.of(context).textTheme.bodyMedium!.color))
                              ]
                            ),
                          )
                      ),
                      const SizedBox(height: 50),
                      if (Platform.isIOS)
                        ...[
                          Padding(padding: const EdgeInsets.all(10), child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: (_uiState == _UiState.noLocalFoundRemote || (_remoteAccountInitialized && _remoteAccount.getProvider() == RemoteModuleProvider.google)) ? null : () async {
                                  setState(() {
                                    _uiState = _UiState.noLocalFoundRemote;
                                    _checkingRemoteViaApple = true;
                                    _checkingRemoteViaGoogle = false;
                                  });
                                  _attemptAppleICloud();
                                },
                                child: Center(child: Row(mainAxisSize:MainAxisSize.min,
                                    children: [
                                      const Padding(padding: EdgeInsets.fromLTRB(0, 5, 0, 0), child: Image(width: 50, image: AssetImage('images/apple_icloud_icon.png'))),
                                      const SizedBox.square(dimension: 10),
                                      Text(RemoteModuleProvider.apple.getDisplayName(), style: const TextStyle(fontSize: 24),),
                                      if (_uiState == _UiState.noLocalFoundRemote && _checkingRemoteViaApple)
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
                            onPressed: (_uiState == _UiState.noLocalFoundRemote || (_remoteAccountInitialized && _remoteAccount.getProvider() == RemoteModuleProvider.apple)) ? null : () {
                              setState(() {
                                _uiState = _UiState.noLocalFoundRemote;
                                _checkingRemoteViaApple = false;
                                _checkingRemoteViaGoogle = true;
                                _googleSignIn.signIn();
                              });
                            },
                            child: Row(mainAxisSize:MainAxisSize.min,
                                children: [
                                  const Image(width: 50, image: AssetImage('images/google_drive_icon.png')),
                                  const SizedBox.square(dimension: 10),
                                  Text(RemoteModuleProvider.google.getDisplayName(), style: const TextStyle(fontSize: 24),),
                                  if (_uiState == _UiState.noLocalFoundRemote && _checkingRemoteViaGoogle)
                                    ...[const SizedBox.square(dimension: 10),
                                      Center(child: CircularProgressIndicator(value: _animationController.value)),]
                                  else
                                    ...[]
                                ]),
                          )
                        ],
                      )),
                      const SizedBox(height: 200),
                  ]),
                  if (_appleICloudNotLoggedIn)
                    ...[
                      AppleICloudFailureWidget(retryFunction: () {
                        setState(() {
                          _uiState = _UiState.noLocalTryingRemote;
                          _checkingRemoteViaApple = false;
                          _checkingRemoteViaGoogle = false;
                          _appleICloudNotLoggedIn = false;
                        });
                      })
                    ]
              ]
            )
          ]
          else if (_uiState == _UiState.localFailedDecryption)
            ...[
              const Text('Invalid password, try again?', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {
                setState(() {
                  _retrievingPassword = false;
                  _uiState = _UiState.localNeedDecrypting;
                });
              }, child: const Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Yes', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Icon(Icons.restart_alt)
                ]))),
              const SizedBox(height: 100),
            ]
          else
            ...[
              const Center(child: Text('Loading existing wallet...', style: TextStyle(fontSize: 24))),
              const SizedBox(height: 50),
              Center(child: CircularProgressIndicator(value: _animationController.value)),
              const SizedBox(height: 100),
            ],
        ],
      ),
    ));
  }

}