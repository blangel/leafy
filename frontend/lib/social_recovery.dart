
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/wallet.dart';
import 'package:leafy/widget/address.dart';
import 'package:leafy/widget/wallet_password.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:settings_ui/settings_ui.dart';

class SocialRecoveryPage extends StatefulWidget {

  const SocialRecoveryPage({super.key});

  @override
  State<SocialRecoveryPage> createState() => _SocialRecoveryState();

}

// social recovery is the following functions:
// (1) Setup
//   (1.a) as user
//   (1.b) as friend/second-device
// (2) Recovery
//   (2.a) request help of friend (could be self)
//   (2.b) respond to friend's request of help

class _SocialRecoveryState extends State<SocialRecoveryPage> {

  final AssetImage _restoreImage = const AssetImage('images/restore.gif');

  final List<String> _companionIds = [];
  bool addedSelf = false;

  _SocialKeyPair? _socialKeyPair;
  bool _attemptDataDecrypt = false;

  String? _encryptedData;

  String? _assistingWithCompanionId;

  late double originalBrightness;

  bool _retrievingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadCompanionIds();
    _createSocialEphemeralKeyPair();
    _setRevertibleBrightness();
  }

  @override
  void dispose() {
    _setBrightness(originalBrightness);
    super.dispose();
  }

  Future<void> _setRevertibleBrightness() async {
    originalBrightness = await ScreenBrightness().system;
    _setBrightness(1.0);
  }

  Future<void> _setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
  }

  void _loadCompanionIds() async {
    var companionIds = await getCompanionIds();
    setState(() {
      _companionIds.addAll(companionIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as SocialRecoveryArguments;
    if (!addedSelf) {
      setState(() {
        addedSelf = true;
        _companionIds.add(arguments.remoteAccountId);
      });
    }
    if (arguments.assistingWithCompanionId != null) {
      setState(() {
        _assistingWithCompanionId = arguments.assistingWithCompanionId;
      });
    }
    switch (arguments.type) {
      case SocialRecoveryType.walletPassword:
        if (!_retrievingPassword) {
          Future.microtask(() {
            _retrievingPassword = true;
            showDialog<String>(
              context: context,
              builder: (BuildContext context) =>
              const WalletPasswordDialog(newPassword: false, unknownUsage: true),
            ).then((password) {
              if (context.mounted) {
                Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recovery, remoteAccountId: arguments.remoteAccountId, walletPassword: password));
              }
            });
          });
        }
        return buildScaffold(context, 'Recovery: Wallet Password', const Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.all(20), child: Text('Provide your wallet password, if any', style: TextStyle(fontSize: 24))),
              SizedBox(height: 150),
            ]
        ));
      case SocialRecoveryType.branch:
        return buildScaffold(context, 'Recovery', Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                    title: const Text('Recover'),
                    tiles: <SettingsTile>[
                      SettingsTile.navigation(
                        leading: const Icon(Icons.restore),
                        title: const Text('Your Account'),
                        value: const Text(''),
                        onPressed: (context) {
                          Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recovery, remoteAccountId: arguments.remoteAccountId, walletPassword: arguments.walletPassword));
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: const Text('Setup Recovery Device'),
                    tiles: <SettingsTile>[
                      SettingsTile.navigation(
                        leading: const Icon(Icons.security_update_good),
                        title: const Text('for Your Account'),
                        value: const Text(''),
                        onPressed: (context) {
                          Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.setup, remoteAccountId: arguments.remoteAccountId, walletPassword: arguments.walletPassword));
                        },
                      ),
                      SettingsTile.navigation(
                        leading: const Icon(Icons.person_add_alt_1),
                        title: const Text('for a Companion'),
                        value: const Text(''),
                        onPressed: (context) {
                          Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.setupCompanion, remoteAccountId: arguments.remoteAccountId, walletPassword: arguments.walletPassword));
                        },
                      ),
                    ],
                  ),
                  if (_companionIds.isNotEmpty)
                    SettingsSection(
                      title: const Text("You can assist the following companions in recovery:"),
                      tiles: <SettingsTile>[
                        for ( var companionId in _companionIds ) SettingsTile.navigation(
                          leading: const Icon(Icons.email_outlined),
                          title: Text(arguments.remoteAccountId == companionId ? "$companionId  (self)" : companionId),
                          value: const Text(''),
                          onPressed: (context) {
                            Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recoveryCompanion, remoteAccountId: arguments.remoteAccountId, assistingWithCompanionId: companionId, walletPassword: arguments.walletPassword));
                          },
                        )
                      ],
                    )
                ],
              )),
            ]
        ));
      case SocialRecoveryType.setup:
        return buildScaffold(context, 'Setup Recovery', Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.all(20), child: Center(child: Image(height: 150, image: _restoreImage))),
              if (_encryptedData == null)
                ...[
                  const Padding(padding: EdgeInsets.all(10),
                    child: Row(
                        children: [
                          Icon(Icons.qr_code_scanner),
                          SizedBox(width: 10),
                          Text("Scan QR", style: TextStyle(fontSize: 18))
                        ]
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(height: 300, child: MobileScanner(
                        controller: MobileScannerController(
                            returnImage: true,
                            detectionSpeed: DetectionSpeed.normal,
                            facing: CameraFacing.back
                        ),
                        onDetect: (capture) {
                          if (capture.barcodes.isNotEmpty && (capture.barcodes.first.rawValue != null)) {
                            _validateCompanionPublicKey(capture.barcodes.first.rawValue!, arguments.remoteAccountId);
                          }
                        },
                      ))),
                  const Padding(padding: EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(Icons.content_paste_go),
                          SizedBox(width: 10),
                          Text("Paste", style: TextStyle(fontSize: 18))
                        ],
                      )
                  ),
                  Padding(padding: const EdgeInsets.all(10),
                      child: TextField(
                        showCursor: true,
                        keyboardType: TextInputType.none,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Companion Data',
                        ),
                        onChanged: (data) {
                          _validateCompanionPublicKey(data, arguments.remoteAccountId);
                        },
                      )
                  )
                ]
              else
                ...[
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text("Provide your companion with the following data to finish the process.", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color))
                  ),
                  Center(
                    child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child:
                    Container(
                        color: Colors.white,
                        child: QrImageView(
                          data: _encryptedData!,
                          version: QrVersions.auto,
                          size: 175.0,
                        )
                    ),
                    ),
                  ),
                  CopyableDataWidget(data: _encryptedData!, shorten: true,),
                  Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(onPressed: () {
                        Navigator.pop(context);
                      }, icon: const Icon(Icons.navigate_next), label: const Text("Done")))
                ]
            ]));
      case SocialRecoveryType.setupCompanion:
        return buildScaffold(context, 'Setup Recovery as a Companion', Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_attemptDataDecrypt)
                ...[
                  Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Center(child: Image(height: 150, image: _restoreImage))),
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text("To start the process, provide person desiring you to be a companion with the following data ", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color))),
                  if (_socialKeyPair != null)
                    ...[
                      Center(
                        child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child:
                        Container(
                            color: Colors.white,
                            child: QrImageView(
                              data: _socialKeyPair!.publicKey,
                              version: QrVersions.auto,
                              size: 175.0,
                            )
                        ),
                        ),
                      ),
                      CopyableDataWidget(data: _socialKeyPair!.publicKey, shorten: true,),
                      Align(
                          alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () {
                        setState(() {
                          _attemptDataDecrypt = true;
                        });
                      }, icon: const Icon(Icons.navigate_next), label: const Text("Next"))),
                    ],
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: RichText(text: TextSpan(
                          text: "\n\nFor more information about how Leafy wallets work, ",
                          style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium!.color),
                          children: [
                            TextSpan(text: "see the documentation", style: TextStyle(fontSize: 14, decoration: TextDecoration.underline, color: Theme.of(context).textTheme.bodyMedium!.color),
                                recognizer: TapGestureRecognizer()..onTap = () { launchDocumentation(); }
                            ),
                            TextSpan(text: ".", style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium!.color)),
                          ])
                      ))
                ]
              else
                ...[
                  const Padding(padding: EdgeInsets.all(10),
                    child: Row(
                        children: [
                          Icon(Icons.qr_code_scanner),
                          SizedBox(width: 10),
                          Text("Scan QR", style: TextStyle(fontSize: 18))
                        ]
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(height: 300, child: MobileScanner(
                        controller: MobileScannerController(
                            returnImage: true,
                            detectionSpeed: DetectionSpeed.normal,
                            facing: CameraFacing.back
                        ),
                        onDetect: (capture) {
                          if (capture.barcodes.isNotEmpty && (capture.barcodes.first.rawValue != null)) {
                            _dataDecryptAndSaveForCompanion(capture.barcodes.first.rawValue!);
                          }
                        },
                      ))),
                  const Padding(padding: EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(Icons.content_paste_go),
                          SizedBox(width: 10),
                          Text("Paste", style: TextStyle(fontSize: 18))
                        ],
                      )
                  ),
                  Padding(padding: const EdgeInsets.all(10),
                      child: TextField(
                        showCursor: true,
                        keyboardType: TextInputType.none,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Companion Data',
                        ),
                        onChanged: (data) {
                          _dataDecryptAndSaveForCompanion(data);
                        },
                      )
                  )
                ],
            ])
        );
      case SocialRecoveryType.recovery:
        return buildScaffold(context, 'Social Recovery', Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_attemptDataDecrypt)
                ...[
                  Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Center(child: Image(height: 150, image: _restoreImage))),
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: RichText(text: TextSpan(
                          text: "Use an existing device or a friend's you've setup as a ",
                          style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color),
                          children: [
                            TextSpan(text: "Companion Device", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium!.color)),
                            TextSpan(text: " to assist in recovery.\n\nOn the companion device, click the restore icon in the upper right of the screen.", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color)),
                            TextSpan(text: "\n\nSelect ", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color)),
                            TextSpan(text: arguments.remoteAccountId, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium!.color)),
                            TextSpan(text: " as the account to recover. Then provide your companion with the following data to begin the process.", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color)),
                          ])
                      )),
                  if (_socialKeyPair != null)
                    ...[
                      Center(
                        child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child:
                        Container(
                            color: Colors.white,
                            child: QrImageView(
                              data: _socialKeyPair!.publicKey,
                              version: QrVersions.auto,
                              size: 175.0,
                            )
                        ),
                        ),
                      ),
                      CopyableDataWidget(data: _socialKeyPair!.publicKey, shorten: true,),
                      Align(
                          alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: () {
                        setState(() {
                          _attemptDataDecrypt = true;
                        });
                      }, icon: const Icon(Icons.navigate_next), label: const Text("Next"))),
                    ],
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: RichText(text: TextSpan(
                          text: "\n\nFor more information about how Leafy wallets work, ",
                          style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium!.color),
                          children: [
                            TextSpan(text: "see the documentation", style: TextStyle(fontSize: 14, decoration: TextDecoration.underline, color: Theme.of(context).textTheme.bodyMedium!.color),
                                recognizer: TapGestureRecognizer()..onTap = () { launchDocumentation(); }
                            ),
                            TextSpan(text: ".", style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium!.color)),
                          ])
                      ))
                ]
              else
                ...[
                  const Padding(padding: EdgeInsets.all(10),
                    child: Row(
                        children: [
                          Icon(Icons.qr_code_scanner),
                          SizedBox(width: 10),
                          Text("Scan QR", style: TextStyle(fontSize: 18))
                        ]
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(height: 300, child: MobileScanner(
                        controller: MobileScannerController(
                            returnImage: true,
                            detectionSpeed: DetectionSpeed.normal,
                            facing: CameraFacing.back
                        ),
                        onDetect: (capture) {
                          if (capture.barcodes.isNotEmpty && (capture.barcodes.first.rawValue != null)) {
                            _dataDecryptAndSave(arguments.walletPassword, capture.barcodes.first.rawValue!, arguments.remoteAccountId);
                          }
                        },
                      ))),
                  const Padding(padding: EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(Icons.content_paste_go),
                          SizedBox(width: 10),
                          Text("Paste", style: TextStyle(fontSize: 18))
                        ],
                      )
                  ),
                  Padding(padding: const EdgeInsets.all(10),
                      child: TextField(
                        showCursor: true,
                        keyboardType: TextInputType.none,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Companion Data',
                        ),
                        onChanged: (data) {
                          _dataDecryptAndSave(arguments.walletPassword, data, arguments.remoteAccountId);
                        },
                      )
                  )
                ],
            ])
        );
      case SocialRecoveryType.recoveryCompanion:
        return buildScaffold(context, 'Assist in Social Recovery', Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.all(20), child: Center(child: Image(height: 150, image: _restoreImage))),
              if (_assistingWithCompanionId == null)
                ...[Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Text("Who is requesting assistance in recovery? ", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color))
                ),
                  if (_companionIds.isNotEmpty)
                    ...[
                      Expanded(flex: 1, child: Padding(padding: const EdgeInsets.all(10),
                          child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _companionIds.length,
                              itemBuilder: (context, index) {
                                return Align(alignment: Alignment.centerLeft, child: InkWell(onTap: () {
                                  setState(() {
                                    _assistingWithCompanionId = _companionIds[index];
                                  });
                                }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: TextButton(onPressed: () {
                                      setState(() {
                                        _assistingWithCompanionId = _companionIds[index];
                                      });
                                    }, child: Text(arguments.remoteAccountId == _companionIds[index] ? "${_companionIds[index]}  (self)" : _companionIds[index], style: const TextStyle(fontSize: 18))))
                                ));
                              },
                              separatorBuilder: (BuildContext context, int index) {
                                return Divider(color: Theme
                                    .of(context)
                                    .textTheme
                                    .titleMedium!
                                    .color, indent: 10, endIndent: 10);
                              }
                          ))
                      )
                    ]
                  else
                    Container(),
                ]
              else if (_encryptedData == null)
                ...[
                  const Padding(padding: EdgeInsets.all(10),
                    child: Row(
                        children: [
                          Icon(Icons.qr_code_scanner),
                          SizedBox(width: 10),
                          Text("Scan QR", style: TextStyle(fontSize: 18))
                        ]
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(height: 300, child: MobileScanner(
                        controller: MobileScannerController(
                            returnImage: true,
                            detectionSpeed: DetectionSpeed.normal,
                            facing: CameraFacing.back
                        ),
                        onDetect: (capture) {
                          if (capture.barcodes.isNotEmpty && (capture.barcodes.first.rawValue != null)) {
                            _validateCompanionPublicKey(capture.barcodes.first.rawValue!, arguments.remoteAccountId);
                          }
                        },
                      ))),
                  const Padding(padding: EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(Icons.content_paste_go),
                          SizedBox(width: 10),
                          Text("Paste", style: TextStyle(fontSize: 18))
                        ],
                      )
                  ),
                  Padding(padding: const EdgeInsets.all(10),
                      child: TextField(
                        showCursor: true,
                        keyboardType: TextInputType.none,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Companion Data',
                        ),
                        onChanged: (data) {
                          _validateCompanionPublicKey(data, arguments.remoteAccountId);
                        },
                      )
                  )
                ]
              else
                ...[
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text("Provide your companion with the following data to finish the process.", style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium!.color))
                  ),
                  Center(
                    child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child:
                    Container(
                        color: Colors.white,
                        child: QrImageView(
                          data: _encryptedData!,
                          version: QrVersions.auto,
                          size: 175.0,
                        )
                    ),
                    ),
                  ),
                  CopyableDataWidget(data: _encryptedData!, shorten: true,),
                  Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(onPressed: () {
                        Navigator.pop(context);
                      }, icon: const Icon(Icons.navigate_next), label: const Text("Done")))
                ]
            ]));
    }
  }

  void _dataDecryptAndSave(String? walletPassword, String encryptedData, String remoteAccountId) async {
    String decrypted = await _decryptWithEphemeralSocialPrivateKeyNatively(_socialKeyPair!.privateKey, encryptedData);
    var json = jsonDecode(decrypted);
    if (CompanionRecoveryWalletWrapper.isCompanionRecoveryWalletWrapper(json)) {
      var wrapped = CompanionRecoveryWalletWrapper.fromJson(json);
      json = jsonDecode(wrapped.serializedWallet);
    }
    var remoteAccountIdForWallet = remoteAccountId;
    if (walletPassword != null) {
      remoteAccountIdForWallet = encryptLeafyData(walletPassword, remoteAccountId);
    }
    var wallet = RecoveryWallet.fromJson(remoteAccountIdForWallet, json);
    if (walletPassword != null) {
      final decryptedWallet = decryptWallet(walletPassword, wallet);
      if (decryptedWallet == null) {
        if (mounted) {
          Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.walletPassword, remoteAccountId: remoteAccountId, walletPassword: null));
        }
        return;
      }
      wallet = decryptedWallet;
    }
    await persistLocallyViaBiometric(walletPassword, wallet.firstMnemonic, wallet.secondDescriptor, remoteAccountId);
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _dataDecryptAndSaveForCompanion(String encryptedData) async {
    String decrypted = await _decryptWithEphemeralSocialPrivateKeyNatively(_socialKeyPair!.privateKey, encryptedData);
    var wrapper = CompanionRecoveryWalletWrapper.fromJson(jsonDecode(decrypted));
    await persistCompanionLocallyViaBiometric(wrapper.serializedWallet, wrapper.companionId);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully setup recovery device', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
      Navigator.pop(context);
    }
  }

  void _validateCompanionPublicKey(String publicKeyHex, String self) async {
    bool result = await _validateEphemeralSocialPublicKeyNatively(publicKeyHex);
    if (!result) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid companion data, try again', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
      }
    } else {
      String walletData;
      if (self == _assistingWithCompanionId) {
        walletData = await getRecoveryWalletSerialized();
      } else if (_assistingWithCompanionId == null) {
        walletData = await getRecoveryWalletSerializedForCompanion();
      } else {
        var companionSerialized = await getCompanionIdWalletSerialized(_assistingWithCompanionId!);
        if (companionSerialized == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid companion data', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
          }
          return;
        } else {
          walletData = companionSerialized;
        }
      }
      String encryptedData = await _encryptWithEphemeralSocialPublicKeyNatively(publicKeyHex, walletData);
      setState(() {
        _encryptedData = encryptedData;
      });
    }
  }

  void _createSocialEphemeralKeyPair() async {
    var keyPair = await _createSocialEphemeralKeyPairNatively();
    setState(() {
      _socialKeyPair = keyPair;
    });
  }

  Future<_SocialKeyPair> _createSocialEphemeralKeyPairNatively() async {
    try {
      List<int> jsonBytes = await platform.invokeMethod("createEphemeralSocialKeyPair");
      Map<String, dynamic> json = jsonDecode(utf8.decode(jsonBytes));
      return _SocialKeyPair.fromNativeJson(json);
    } on PlatformException catch (e) {
      throw ArgumentError("failed to createEphemeralSocialKeyPair: $e");
    }
  }

  Future<bool> _validateEphemeralSocialPublicKeyNatively(String publicKeyHex) async {
    try {
      await platform.invokeMethod("validateEphemeralSocialPublicKey", <String, dynamic>{
        'publicKeyHex': publicKeyHex,
      });
      return true;
    } on PlatformException {
      return false;
    }
  }

  Future<String> _encryptWithEphemeralSocialPublicKeyNatively(String publicKeyHex, String data) async {
    List<String> chunks = _splitForEncryptionWrapping(data);
    List<String> encryptedChunks = [];
    for (String chunk in chunks) {
      final encryptedChunk = await _encryptChunkedWithEphemeralSocialPublicKeyNatively(publicKeyHex, chunk);
      encryptedChunks.add(encryptedChunk);
    }
    return jsonEncode(encryptedChunks);
  }

  Future<String> _encryptChunkedWithEphemeralSocialPublicKeyNatively(String publicKeyHex, String data) async {
    try {
      return await platform.invokeMethod("encryptWithEphemeralSocialPublicKey", <String, dynamic>{
        'publicKeyHex': publicKeyHex,
        'data': data,
      });
    } on PlatformException catch (e) {
      throw ArgumentError("failed to encryptWithEphemeralSocialPublicKey: $e");
    }
  }

  Future<String> _decryptWithEphemeralSocialPrivateKeyNatively(String privateKeyHex, String encrypted) async {
    List<dynamic> encryptedChunks = jsonDecode(encrypted);
    List<String> chunks = [];
    for (String encryptedChunk in encryptedChunks) {
      final chunk = await _decryptChunkedWithEphemeralSocialPrivateKeyNatively(privateKeyHex, encryptedChunk);
      chunks.add(chunk);
    }
    return chunks.join();
  }

  Future<String> _decryptChunkedWithEphemeralSocialPrivateKeyNatively(String privateKeyHex, String encrypted) async {
    try {
      return await platform.invokeMethod("decryptWithEphemeralSocialPrivateKey", <String, dynamic>{
        'privateKeyHex': privateKeyHex,
        'encrypted': encrypted,
      });
    } on PlatformException catch (e) {
      throw ArgumentError("failed to decryptWithEphemeralSocialPrivateKey: $e");
    }
  }

  List<String> _splitForEncryptionWrapping(String data) {
    // Leafy uses 4096 RSA keys, split data into 500 length chunks
    List<String> chunks = [];
    int start = 0;
    while (start < data.length) {
      int end = start + 500 < data.length ? start + 500 : data.length;
      chunks.add(data.substring(start, end));
      start += 500;
    }
    return chunks;
  }

}

class _SocialKeyPair {
  final String publicKey;
  final String privateKey;

  _SocialKeyPair({required this.publicKey, required this.privateKey});

  factory _SocialKeyPair.fromNativeJson(Map<String, dynamic> json) {
    return _SocialKeyPair(
      publicKey: json['PublicKey'],
      privateKey: json['PrivateKey'],
    );
  }

}