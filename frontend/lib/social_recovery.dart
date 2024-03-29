
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/apple_icloud_remote_account.dart';
import 'package:leafy/util/google_drive_remote_account.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:leafy/util/wallet.dart';
import 'package:leafy/widget/address.dart';
import 'package:leafy/widget/apple_icloud_failure.dart';
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

  bool _inited = false;
  late String _selfId;
  final List<String> _companionIds = [];
  late String? _walletFirstMnemonic;

  _SocialKeyPair? _socialKeyPair;
  bool _attemptDataDecrypt = false;
  bool _askForRemoteAccountPersistence = false;
  bool _loggingInRemoteAccount = false;
  bool _remoteAccountPersistenceFailed = false;
  CompanionRecoveryWalletWrapper? _companionWallet;

  late final GoogleSignInUtil _googleSignIn;
  late final AppleICloudRemoteAccount _appleICloud;
  RemoteModule? _remoteAccount;
  bool _remoteAccountInitialized = false;
  _RemoteAccountUsage? _remoteAccountUsage;
  bool _loadedRemoteAccountCompanionIds = false;
  bool _appleICloudNotLoggedIn = false;

  String? _encryptedData;

  String? _assistingWithCompanionId;

  late double _originalBrightness;

  bool _retrievingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadCompanionIds();
    _createSocialEphemeralKeyPair();
    _setRevertibleBrightness();
    _googleSignIn = GoogleSignInUtil.create((account) async {
      try {
        if (account != null) {
          if (!_remoteAccountInitialized) {
            _remoteAccount = await GoogleDriveRemoteAccount.create(account);
          }
          _remoteAccountInitialized = true;
          _loadRemoteAccounts();
        }
      } on Exception catch(e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString(), style: const TextStyle(color: Colors.white),),
            backgroundColor: Colors.redAccent,
          ));
        }
      }
      setState(() {
        _loggingInRemoteAccount = false;
      });
    });
    _appleICloud = AppleICloudRemoteAccount.create();
  }

  void _loadRemoteAccounts() async {
    try {
      if (_remoteAccountUsage == _RemoteAccountUsage.persist) {
        var data = _companionWallet!.serializedWallet;
        var encrypted = data;
        if (_walletFirstMnemonic != null) {
          encrypted = encryptLeafyData(_walletFirstMnemonic!, data);
        }
        var result = await _remoteAccount!.persistCompanionData(_companionWallet!.companionId, encrypted);
        if (result) {
          _finalizeAssistanceForCompanion();
          return;
        } else {
          setState(() {
            _remoteAccountPersistenceFailed = true;
          });
        }
      } else if (_remoteAccountUsage == _RemoteAccountUsage.load) {
        _loadCompanionIds();
      }
    } on Exception catch(e) {
      if (mounted) {
        log("exception: $_remoteAccountUsage | ${e.toString()}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: const TextStyle(color: Colors.white),),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  void dispose() {
    _setBrightness(_originalBrightness);
    super.dispose();
  }

  Future<void> _setRevertibleBrightness() async {
    _originalBrightness = await ScreenBrightness().system;
    _setBrightness(1.0);
  }

  Future<void> _setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
  }

  void _loadCompanionIds() async {
    bool localLoadedRemoteAccountCompanionIds = _remoteAccount != null;
    var companionIds = await getCompanionIds(_remoteAccount);
    setState(() {
      _companionIds.clear();
      if (!companionIds.contains(_selfId)) {
        _companionIds.add(_selfId);
      }
      _companionIds.addAll(companionIds);
      _loadedRemoteAccountCompanionIds = localLoadedRemoteAccountCompanionIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as SocialRecoveryArguments;
    if (!_inited) {
      setState(() {
        _inited = true;
        _selfId = arguments.remoteAccountId;
        if (!_companionIds.contains(arguments.remoteAccountId)) {
          _companionIds.add(arguments.remoteAccountId);
        }
        _walletFirstMnemonic = arguments.walletFirstMnemonic;
        if (arguments.remoteAccount != null && !_remoteAccountInitialized) {
          _remoteAccount = arguments.remoteAccount;
          _remoteAccountInitialized = true;
        }
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
                Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recovery, remoteAccountId: arguments.remoteAccountId, remoteProvider: arguments.remoteProvider, walletPassword: password, walletFirstMnemonic: arguments.walletFirstMnemonic));
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
        return buildScaffold(context, 'Recovery', Stack(
          children: [
            Column(
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
                            Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recovery, remoteAccountId: arguments.remoteAccountId, remoteProvider: arguments.remoteProvider, walletPassword: arguments.walletPassword, walletFirstMnemonic: arguments.walletFirstMnemonic));
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
                            Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.setup, remoteAccountId: arguments.remoteAccountId, remoteProvider: arguments.remoteProvider, walletPassword: arguments.walletPassword, walletFirstMnemonic: arguments.walletFirstMnemonic));
                          },
                        ),
                        SettingsTile.navigation(
                          leading: const Icon(Icons.person_add_alt_1),
                          title: const Text('for a Companion'),
                          value: const Text(''),
                          onPressed: (context) {
                            Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.setupCompanion, remoteAccountId: arguments.remoteAccountId, remoteProvider: arguments.remoteProvider, walletPassword: arguments.walletPassword, walletFirstMnemonic: arguments.walletFirstMnemonic));
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
                              var remoteAccountArgument = _remoteAccountInitialized ? _remoteAccount : null;
                              Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.recoveryCompanion, remoteAccountId: arguments.remoteAccountId, remoteProvider: arguments.remoteProvider, assistingWithCompanionId: companionId, walletPassword: arguments.walletPassword, walletFirstMnemonic: arguments.walletFirstMnemonic, remoteAccount: remoteAccountArgument));
                            },
                          ),
                          if (!_loadedRemoteAccountCompanionIds)
                            SettingsTile.navigation(
                              leading: const Icon(Icons.cloud_sync_outlined),
                              title: Text('Sync with ${arguments.remoteProvider.getDisplayName()}'),
                              value: const Text(''),
                              onPressed: (context) {
                                setState(() {
                                  _loadedRemoteAccountCompanionIds = true;
                                  _remoteAccountUsage = _RemoteAccountUsage.load;
                                  switch (arguments.remoteProvider) {
                                    case RemoteModuleProvider.google:
                                      _googleSignIn.signIn();
                                      break;
                                    case RemoteModuleProvider.apple:
                                      _attemptAppleICloud();
                                      break;
                                    default:
                                      throw Exception("programming error: unhandled provider type ${arguments.remoteProvider.name}");
                                  }
                                });
                              },
                            ),
                        ],
                      )
                  ],
                )),
              ]
            ),
            if (_appleICloudNotLoggedIn)
              ...[
                AppleICloudFailureWidget(retryFunction: () {
                  setState(() {
                    _appleICloudNotLoggedIn = false;
                  });
                })
              ]
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
                  const Padding(padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Text("On a companion device, begin the process by setting up a recovery device for a companion and then either scan or paste the data here.", style: TextStyle(fontSize: 16))
                  ),
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
                            _validateCompanionPublicKey(arguments.walletPassword, arguments.walletFirstMnemonic, capture.barcodes.first.rawValue!, arguments.remoteAccountId);
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
                          _validateCompanionPublicKey(arguments.walletPassword, arguments.walletFirstMnemonic, data, arguments.remoteAccountId);
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
                  CopyableDataWidget(data: _encryptedData!),
                  Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(onPressed: () {
                        setNotNeedingCompanionDeviceBackup();
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
                      CopyableDataWidget(data: _socialKeyPair!.publicKey),
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
              else if (_askForRemoteAccountPersistence)
                ...[
                  Padding(padding: const EdgeInsets.all(20), child: Text(_remoteAccountPersistenceFailed ? 'Failed to save companion data on your ${arguments.remoteProvider.getDisplayName()} account (however, it is already successfully saved locally).'
                      : 'Companion data successfully saved locally!', style: const TextStyle(fontSize: 24))),
                  Padding(padding: const EdgeInsets.all(20), child: Text(_remoteAccountPersistenceFailed ? 'Would you like to retry saving the companion data on your ${arguments.remoteProvider.getDisplayName()}?'
                      : 'Would you want to persist this companion data on your ${arguments.remoteProvider.getDisplayName()} as well?', style: const TextStyle(fontSize: 24))),
                  Padding(padding: const EdgeInsets.all(20), child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _loggingInRemoteAccount ? null : () {
                          _finalizeAssistanceForCompanion();
                        },
                        child: const Text("No", style: TextStyle(fontSize: 24)),
                      ),
                      TextButton(
                        onPressed: _loggingInRemoteAccount ? null : () {
                          setState(() {
                            _loggingInRemoteAccount = true;
                            _remoteAccountUsage = _RemoteAccountUsage.persist;
                            switch (arguments.remoteProvider) {
                              case RemoteModuleProvider.google:
                                _googleSignIn.signIn();
                                break;
                              case RemoteModuleProvider.apple:
                                _attemptAppleICloud();
                                break;
                              default:
                                throw Exception("programming error: unhandled provider type ${arguments.remoteProvider.name}");
                            }
                          });
                        },
                        child: Text(_loggingInRemoteAccount ? 'Logging-in...' : 'Yes', style: const TextStyle(fontSize: 24)),
                      ),
                    ]
                  )),
                  const SizedBox(height: 150),
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
                            TextSpan(text: "\n\nSelect ", style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium!.color)),
                            TextSpan(text: arguments.remoteAccountId, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium!.color)),
                            TextSpan(text: " as the account to recover. Then provide your companion with the following data to begin the process.", style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium!.color)),
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
                      CopyableDataWidget(data: _socialKeyPair!.publicKey),
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
                            _dataDecryptAndSave(arguments.walletPassword, capture.barcodes.first.rawValue!, arguments.remoteAccountId, arguments.remoteProvider);
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
                          _dataDecryptAndSave(arguments.walletPassword, data, arguments.remoteAccountId, arguments.remoteProvider);
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
                            _validateCompanionPublicKey(arguments.walletPassword, arguments.walletFirstMnemonic, capture.barcodes.first.rawValue!, arguments.remoteAccountId);
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
                          _validateCompanionPublicKey(arguments.walletPassword, arguments.walletFirstMnemonic, data, arguments.remoteAccountId);
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
                  CopyableDataWidget(data: _encryptedData!),
                  Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(onPressed: () {
                        Navigator.pop(context);
                      }, icon: const Icon(Icons.navigate_next), label: const Text("Done")))
                ]
            ]));
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
        _loadRemoteAccounts();
      } else {
        _failedToLoadRemote("No ${RemoteModuleProvider.apple.getDisplayShortName()} account id found");
      }
    }
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

  void _dataDecryptAndSave(String? walletPassword, String encryptedData, String remoteAccountId, RemoteModuleProvider remoteProvider) async {
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
    var wallet = RecoveryWallet.fromJson(remoteAccountIdForWallet, remoteProvider, json);
    if (walletPassword != null) {
      final decryptedWallet = decryptWallet(walletPassword, wallet);
      if (decryptedWallet == null) {
        if (mounted) {
          Navigator.popAndPushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.walletPassword, remoteAccountId: remoteAccountId, remoteProvider: remoteProvider, walletPassword: null, walletFirstMnemonic: _walletFirstMnemonic));
        }
        return;
      }
      wallet = decryptedWallet;
    }
    await persistLocally(walletPassword, wallet.firstMnemonic, wallet.secondDescriptor, remoteAccountId, remoteProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully recovered wallet! Re-authenticate.', overflow: TextOverflow.ellipsis,), duration: Duration(seconds: 7), showCloseIcon: true));
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _dataDecryptAndSaveForCompanion(String encryptedData) async {
    String decrypted = await _decryptWithEphemeralSocialPrivateKeyNatively(_socialKeyPair!.privateKey, encryptedData);
    var wrapper = CompanionRecoveryWalletWrapper.fromJson(jsonDecode(decrypted));
    await persistCompanionLocally(wrapper.serializedWallet, wrapper.companionId);
    setState(() {
      _companionWallet = wrapper;
      _askForRemoteAccountPersistence = true;
    });
  }

  void _finalizeAssistanceForCompanion() {
    if (mounted) {
      setState(() {
        _loggingInRemoteAccount = false;
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully setup recovery device', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
      Navigator.pop(context);
    }
  }

  void _validateCompanionPublicKey(String? walletPassword, String? firstSeedMnemonic, String publicKeyHex, String self) async {
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
        walletData = await getRecoveryWalletSerializedForCompanion(walletPassword);
      } else {
        var companionSerialized = await getCompanionIdWalletSerialized(_assistingWithCompanionId!, _remoteAccount, firstSeedMnemonic);
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

enum _RemoteAccountUsage {
  persist,
  load;
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