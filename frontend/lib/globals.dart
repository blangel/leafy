
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/mempool_space_connectivity.dart';
import 'package:leafy/util/price_service.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:leafy/util/wallet.dart';
import 'package:url_launcher/url_launcher.dart';

const platform = MethodChannel('leafy/core');

// TODO - user configured network?
final BitcoinClient bitcoinClient = kDebugMode ? MempoolSpaceClient.regtest() : MempoolSpaceClient.mainnet();

const String documentationPasswordUrl = 'https://github.com/blangel/leafy?tab=readme-ov-file#3-optional-passwordpassphrase';
final Uri documentationUri = Uri.parse('https://github.com/blangel/leafy/blob/main/README.md');
Future<void> launchDocumentation([String? override]) async {
  var url = override == null ? documentationUri : Uri.parse(override);
  if (!await launchUrl(url)) {
    throw Exception('Could not launch $url');
  }
}

String globalRemoteAccountId = "";

final PriceService priceService = CoinbasePriceService();

final ThemeData lightTheme = ThemeData.light(useMaterial3: true);

final ThemeData darkTheme = ThemeData.dark(useMaterial3: true);

ThemeData getLightTheme() {
  return lightTheme.copyWith(textTheme: GoogleFonts.outfitTextTheme(lightTheme.textTheme));
}

ThemeData getDarkTheme() {
  return darkTheme.copyWith(textTheme: GoogleFonts.outfitTextTheme(darkTheme.textTheme));
}

Scaffold buildHomeScaffold(BuildContext context, String title, Widget body) {
  return _buildScaffold(context, title, body, false, _Recovery.none);
}

Scaffold buildHomeScaffoldWithRestore(BuildContext context, String title, String? walletPassword, String? firstMnemonic, Widget body) {
  return _buildScaffold(context, title, body, false, _Recovery(walletPassword, firstMnemonic));
}

Scaffold buildScaffold(BuildContext context, String title, Widget body) {
  return _buildScaffold(context, title, body, true, _Recovery.none);
}

class _Recovery {
  static final _Recovery none = _Recovery(null, null);

  final String? walletPassword;

  final String? firstMnemonic;

  _Recovery(this.walletPassword, this.firstMnemonic);
}

Scaffold _buildScaffold(BuildContext context, String title, Widget body, bool addLeading, _Recovery recovery) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(title),
      actions: recovery != _Recovery.none ? [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String value) {
            if (value == 'recovery') {
              Navigator.pushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.branch, remoteAccountId: globalRemoteAccountId, walletPassword: recovery.walletPassword, walletFirstMnemonic: recovery.firstMnemonic));
            } else if (value == 'settings') {
              // TODO - settings
            } else {
              throw Exception("programming error");
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'recovery',
              child: Row(
                children: [
                  Icon(Icons.restore),
                  Padding(padding: EdgeInsets.only(left: 10), child: Text("Recovery")),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  Padding(padding: EdgeInsets.only(left: 10), child: Text("Settings")),
                ],
              ),
            ),
          ],
        )
      ] : [],
      leading: (addLeading ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ) : null),
      automaticallyImplyLeading: false,
    ),
    body: body,
  );
}

enum EffectiveDeviceType {
  mobile,
  tablet,
  desktop
}

EffectiveDeviceType getEffectiveDeviceType(BuildContext context) {
  Size size = MediaQuery.of(context).size;
  double dimension = size.width > size.height ? size.height : size.width;
  if (size.width > 900) {
    return EffectiveDeviceType.desktop;
  } else if (dimension > 600) {
    return EffectiveDeviceType.tablet;
  } else {
    return EffectiveDeviceType.mobile;
  }
}

Future<void> launchWebUrl(String urlString) async {
  Uri url = Uri.parse(urlString);
  if (!await launchUrl(url)) {
    throw 'Could not launch $urlString';
  }
}

String formatCurrency(double amount) {
  NumberFormat formatter = NumberFormat.simpleCurrency(locale: 'en_US', name: 'USD');
  return formatter.format(amount);
}

class KeyArguments {
  final String firstMnemonic;
  final String secondDescriptor;
  final String? secondMnemonic;
  final String? walletPassword;

  KeyArguments({required this.firstMnemonic, required this.secondDescriptor, required this.secondMnemonic, required this.walletPassword});
}

class TransactionsArguments {
  final List<Transaction> transactions;
  // in case a referencable tx needs fee-bumping; needs keys, set of transactions(utxos) and a change-address
  final KeyArguments keyArguments;
  final String changeAddress;

  TransactionsArguments({required this.transactions, required this.keyArguments,
    required this.changeAddress});
}

class TransactionArgument {
  final Transaction transaction;
  // in case a referencable tx needs fee-bumping; needs keys, set of transactions(utxos) and a change-address
  final KeyArguments keyArguments;
  final List<Transaction> transactions;
  final String changeAddress;

  TransactionArgument({required this.transaction, required this.keyArguments,
    required this.transactions, required this.changeAddress});
}

class AddressArguments {
  final List<AddressInfo> addresses;
  final Map<String, List<Transaction>> transactions;
  // in case a referencable tx needs fee-bumping; needs keys, set of transactions(utxos) and a change-address
  final KeyArguments keyArguments;
  final List<Transaction> allTransactions;
  final String changeAddress;

  AddressArguments({required this.addresses, required this.transactions,
    required this.keyArguments, required this.allTransactions, required this.changeAddress});
}

class AddressDetailArgument {
  final AddressInfo addressInfo;
  final List<Transaction>? transactions;
  // in case a referencable tx needs fee-bumping; needs keys, set of transactions(utxos) and a change-address
  final KeyArguments keyArguments;
  final List<Transaction> allTransactions;
  final String changeAddress;

  AddressDetailArgument({required this.addressInfo, required this.transactions,
    required this.keyArguments, required this.allTransactions, required this.changeAddress});
}

class AddressArgument {
  final String address;
  // in case a referencable tx needs fee-bumping; needs keys, set of transactions(utxos) and a change-address
  final KeyArguments keyArguments;
  final List<Transaction> transactions;
  final String changeAddress;

  AddressArgument({required this.address, required this.keyArguments,
    required this.transactions, required this.changeAddress});
}

class CreateTransactionArguments {
  final KeyArguments keyArguments;
  final List<Transaction> transactions;
  final String changeAddress;
  final Transaction? toReplace;

  CreateTransactionArguments({required this.keyArguments,
    required this.transactions, required this.changeAddress, this.toReplace});
}

// SocialRecoveryType determines what UI to display in recovery
enum SocialRecoveryType {
  branch, walletPassword, setup, setupCompanion, recovery, recoveryCompanion;
}

class SocialRecoveryArguments {
  final SocialRecoveryType type;
  final String? walletPassword;
  final String? walletFirstMnemonic;
  final String remoteAccountId;
  final String? assistingWithCompanionId;

  SocialRecoveryArguments({required this.type, required this.walletPassword, required this.walletFirstMnemonic, required this.remoteAccountId, this.assistingWithCompanionId});
}

// TODO - update to use biometric_storage (https://pub.dev/packages/biometric_storage) instead of flutter_secure_storage ?

Future<void> persistLocallyViaBiometric(String? password, String firstMnemonic, String secondDescriptor, String remoteAccountId) async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  var firstSeedData = firstMnemonic;
  var secondDescriptorData = secondDescriptor;
  var remoteAccountIdData = remoteAccountId;
  if (password != null) {
    firstSeedData = encryptLeafyData(password, firstSeedData);
    secondDescriptorData = encryptLeafyData(password, secondDescriptorData);
    remoteAccountIdData = encryptLeafyData(password, remoteAccountIdData);
  }
  storage.write(key: 'leafy:firstMnemonic', value: firstSeedData);
  storage.write(key: 'leafy:secondDescriptor', value: secondDescriptorData);
  storage.write(key: 'leafy:remoteAccountId', value: remoteAccountIdData);
}

Future<RecoveryWallet?> getRecoveryWalletViaBiometric() async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  final firstMnemonic = await storage.read(key: 'leafy:firstMnemonic');
  final secondDescriptor = await storage.read(key: 'leafy:secondDescriptor');
  final remoteAccountId = await storage.read(key: 'leafy:remoteAccountId');
  if ((firstMnemonic != null) && (secondDescriptor != null) && (remoteAccountId != null)) {
    return RecoveryWallet(firstMnemonic: firstMnemonic, secondDescriptor: secondDescriptor, remoteAccountId: remoteAccountId);
  }
  return null;
}

Future<List<String>> getCompanionIds(RemoteModule? remoteModule) async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  var keyPrefix = 'leafy:companion:';
  var all = await storage.readAll();
  var local = all.keys
      .where((element) => element.startsWith(keyPrefix))
      .map((element) => element.substring(keyPrefix.length)).toList();
  var set = Set<String>.from(local);

  if (remoteModule != null) {
    var remote = await remoteModule.getCompanionIds();
    set.addAll(remote);
  }
  return set.toList();
}

Future<String> getRecoveryWalletSerialized() async {
  RecoveryWallet? wallet = await getRecoveryWalletViaBiometric();
  if (wallet == null) {
    throw Exception("no wallet found");
  }
  return jsonEncode(wallet.toJson());
}

Future<String> getRecoveryWalletSerializedForCompanion(String? walletPassword) async {
  RecoveryWallet? wallet = await getRecoveryWalletViaBiometric();
  if (wallet == null) {
    throw Exception("no wallet found");
  }
  String? companionId = wallet.remoteAccountId;
  if (walletPassword != null) {
    companionId = decryptLeafyData(walletPassword, companionId, 1);
  }
  var walletSerialized = jsonEncode(wallet.toJson());
  CompanionRecoveryWalletWrapper wrapper = CompanionRecoveryWalletWrapper(companionId: companionId!, serializedWallet: walletSerialized);
  return jsonEncode(wrapper.toJson());
}

Future<String?> getCompanionIdWalletSerialized(String companionId, RemoteModule? remoteModule) async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  String? walletSerialized = await storage.read(key: 'leafy:companion:$companionId');
  if (walletSerialized == null) {
    if (remoteModule != null) {
      walletSerialized = await remoteModule.getCompanionData(companionId);
      if (walletSerialized == null) {
        return null;
      }
    } else {
      return null;
    }
  }
  CompanionRecoveryWalletWrapper wrapper = CompanionRecoveryWalletWrapper(companionId: companionId, serializedWallet: walletSerialized);
  return jsonEncode(wrapper.toJson());
}

Future<void> persistCompanionLocallyViaBiometric(String serialized, String companionId) async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  storage.write(key: 'leafy:companion:$companionId', value: serialized);
}