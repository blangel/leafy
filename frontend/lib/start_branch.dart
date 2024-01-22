import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/google_drive_remote_account.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:leafy/util/wallet.dart';

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

  late final RemoteModule _remoteAccount;

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
          Navigator.popAndPushNamed(context, '/timelock-recovery');  // TODO - recovery via timelock path
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
        _remoteAccount = await GoogleDriveRemoteAccount.create(account!);
        var encryptedContent = await _remoteAccount.getEncryptedSecondSeed();
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
              Navigator.popAndPushNamed(context, '/timelock-recovery');  // TODO - recovery via timelock path
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
    final decrypted = decryptSecondSeedMnemonic(_recoveryWallet!.firstMnemonic, _encryptedMnemonicContent!);
    if (decrypted != null) {
      Navigator.popAndPushNamed(context, '/wallet', arguments: KeyArguments(firstMnemonic: _recoveryWallet!.firstMnemonic, secondMnemonic: decrypted, secondDescriptor: _recoveryWallet!.secondDescriptor));
      return;
    }
    // TODO - if local is corrupted, attempt /social-recovery, otherwise need /timelock-recovery
    // TODO - should ask user; want to try social-recovery? otherwise need /timelock-recovery
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

}