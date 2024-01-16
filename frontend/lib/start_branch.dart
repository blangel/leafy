import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/google_drive_util.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:leafy/util/wallet.dart';

// Possible branches and their handling:
// (0) [normal] locally have first-mnemonic, second-descriptor and second-mnemonic via cloud-account => '/wallet'
// (1) [new | social] nothing locally and nothing on cloud-account => ask for '/social', otherwise '/new'
// (2) [recovery] locally have first-mnemonic, second-descriptor but no cloud-account access => '/recovery'
// (3) [social] nothing locally, and second-mnemonic via cloud-account => '/social'

// LeafyStartPage determines if a user has an existing account, branching
// to the proper page depending upon existence

class LeafyStartPage extends StatefulWidget {
  const LeafyStartPage({super.key});

  @override
  State<LeafyStartPage> createState() => _LeafyStartState();
}

enum _UiState {
  // loading states; indeterminate branch
  loading, foundLocal, foundRemote, noLocal, noRemote,
  // known state
  foundLocalAndRemote, // branch (0)[normal] above
  foundLocalNoRemote, // branch (2)[recovery] above
  foundRemoteNoLocal, // branch (3)[social] above
  foundNothing // branch (1)[new|social] above
}

class _LeafyStartState extends State<LeafyStartPage> with TickerProviderStateMixin {

  late final GoogleSignInUtil _googleSignIn;

  late AnimationController _animationController;

  _UiState _uiState = _UiState.loading;
  RecoveryWallet? _recoveryWallet;
  String? _encryptedMnemonicContent;
  String? _remoteAccountId;

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
    // TODO - validate that wallet.remoteAccountId == account.email
    getRecoveryWalletViaBiometric().then((wallet) {
      if (wallet != null) {
        if (_uiState == _UiState.foundRemote) {
          setState(() {
            _uiState = _UiState.foundLocalAndRemote;
            _recoveryWallet = wallet;
            decryptMnemonicContent();
          });
        } else if (_uiState == _UiState.noRemote) {
          setState(() {
            _uiState = _UiState.foundLocalNoRemote;
            _recoveryWallet = wallet;
          });
          Navigator.popAndPushNamed(context, '/recovery');  // TODO - recovery via timelock path
        } else {
          setState(() {
            _uiState = _UiState.foundLocal;
            _recoveryWallet = wallet;
          });
        }
      } else {
        if (_uiState == _UiState.foundRemote) {
          setState(() {
            _uiState = _UiState.foundRemoteNoLocal;
          });
          Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recovery, remoteAccountId: _remoteAccountId!));
        } else if (_uiState == _UiState.noRemote) {
          setState(() {
            _uiState = _UiState.foundNothing;
          });
          Navigator.popAndPushNamed(context, '/new');
        } else {
          setState(() {
            _uiState = _UiState.noLocal;
          });
        }
      }
    });
    _googleSignIn = GoogleSignInUtil.create((account) async {
      try {
        var encryptedContent = await getLeafyMnemonicContent(account!);
        globalRemoteAccountId = account.email;
        if (context.mounted) {
          if (encryptedContent != null) {
            if (_uiState == _UiState.foundLocal) {
              setState(() {
                _uiState = _UiState.foundLocalAndRemote;
                _encryptedMnemonicContent = encryptedContent;
                _remoteAccountId = account.email;
                decryptMnemonicContent();
              });
            } else if (_uiState == _UiState.noLocal) {
              setState(() {
                _uiState = _UiState.foundRemoteNoLocal;
                _remoteAccountId = account.email;
                _encryptedMnemonicContent = encryptedContent;
              });
              Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recovery, remoteAccountId: account.email));
            } else {
              setState(() {
                _uiState = _UiState.foundRemote;
                _remoteAccountId = account.email;
                _encryptedMnemonicContent = encryptedContent;
              });
            }
          } else {
            if (_uiState == _UiState.foundLocal) {
              setState(() {
                _uiState = _UiState.foundLocalNoRemote;
              });
              Navigator.popAndPushNamed(context, '/recovery');  // TODO - recovery via timelock path
            } else if (_uiState == _UiState.noLocal) {
              setState(() {
                _uiState = _UiState.foundNothing;
              });
              Navigator.popAndPushNamed(context, '/new');
            } else {
              setState(() {
                _uiState = _UiState.noRemote;
              });
            }
          }
        }
      } on Exception catch(e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${e.toString()}; setting up a new wallet", style: const TextStyle(color: Colors.white),),
            backgroundColor: Colors.redAccent,
          ));
          Navigator.popAndPushNamed(context, '/new');
        }
      }
    });
  }

  void decryptMnemonicContent() {
    if ((_encryptedMnemonicContent == null) || (_recoveryWallet == null)) {
      return;
    }
    List<int> firstMnemonicBytes = utf8.encode(_recoveryWallet!.firstMnemonic);
    Digest firstMnemonicSha = sha256.convert(firstMnemonicBytes);
    final encryptionKey = encrypt.Key.fromBase64(base64Url.encode(firstMnemonicSha.bytes));
    final fernet = encrypt.Fernet(encryptionKey);
    final encrypter = encrypt.Encrypter(fernet);
    try {
      final decrypted = encrypter.decrypt64(_encryptedMnemonicContent!);
      var split = decrypted.split(' ');
      if (split.length == 24) {
        Navigator.popAndPushNamed(context, '/wallet', arguments: KeyArguments(firstMnemonic: _recoveryWallet!.firstMnemonic, secondMnemonic: decrypted, secondDescriptor: _recoveryWallet!.secondDescriptor));
        return;
      }
      log("invalid decrypted second mnemonic (length of ${split.length})");
    } catch (e) {
      log("failed to decrypt: ${e.toString()}");
    }
    // TODO - if local is corrupted, attempt /social-recovery, otherwise need /recovery
    // TODO - should ask user; want to try social-recovery? otherwise need /recovery
    Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recovery, remoteAccountId: _remoteAccountId!));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _googleSignIn.signIn();
    return buildScaffold(context, 'Wallet Check', Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Text('Checking for existing wallet...', style: TextStyle(fontSize: 24))),
          const SizedBox(height: 50),
          Center(child: CircularProgressIndicator(value: _animationController.value)),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              TextButton(onPressed: () {
                _googleSignIn.signIn();
              }, child: const Text('Retry'))
            ],
          )
        ],
      ),
    ));
  }

  Future<String?> getLeafyMnemonicContent(GoogleSignInAccount account) async {
    final driveApi = await GoogleDriveUtil.create(account);
    var mnemonicFile = await driveApi.getMnemonicFile();
    if (mnemonicFile == null) {
      return null;
    }
    if ((mnemonicFile.trashed != null) && mnemonicFile.trashed!) {
      await driveApi.restore(mnemonicFile);
    }
    return driveApi.getContent(mnemonicFile.id!);
  }

}