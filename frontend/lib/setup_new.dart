import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _advancedTileExpanded = false;
  final TextEditingController _passwordController = TextEditingController();
  String? _password;
  bool _showPassword = false;

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
          _remoteAccount = await GoogleDriveRemoteAccount.create(account);
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
    _passwordController.dispose();
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
        )),
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
                      _passwordController.clear();
                      _showPassword = false;
                    });
                    return;
                  }
                  showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Wallet Password'),
                      content: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                          return AutofillGroup(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                                  child: RichText(text: TextSpan(text: "Leafy does not recommend using a password. ",
                                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium!.color),
                                      children: [
                                        TextSpan(text: "Read the documentation", style: TextStyle(fontSize: 14, decoration: TextDecoration.underline, color: Theme.of(context).textTheme.bodyMedium!.color),
                                          recognizer: TapGestureRecognizer()..onTap = () { launchDocumentation(documentationPasswordUrl); }
                                        ),
                                        TextSpan(text: " for further context in terms of the risks and rationale for setting a password.", style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium!.color))
                                      ]
                                    ),
                                  ),
                              ),
                              TextField(
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    hintText: 'Enter a wallet password',
                                    suffixIcon: IconButton(
                                      icon: _showPassword ? const Icon(Icons.visibility_off) : const Icon(Icons.visibility),
                                      onPressed: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                    ),
                                  ),
                                  obscureText: !_showPassword,
                                  enableSuggestions: false,
                                  autocorrect: false
                              )
                            ],
                          ));
                        }
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _password = null;
                              _passwordController.clear();
                              _showPassword = false;
                            });
                            Navigator.pop(context, 'Cancel');
                          },
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _password = _passwordController.text;
                            });
                            TextInput.finishAutofillContext();
                            Navigator.pop(context, 'Use');
                          },
                          child: const Text('Use'),
                        ),
                      ],
                    ),
                  );
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