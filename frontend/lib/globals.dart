
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/mempool_space_connectivity.dart';
import 'package:leafy/util/price_service.dart';
import 'package:leafy/util/wallet.dart';
import 'package:url_launcher/url_launcher.dart';

const platform = MethodChannel('leafy/core');

// TODO - user configured network?
final BitcoinClient bitcoinClient = kDebugMode ? MempoolSpaceClient.regtest() : MempoolSpaceClient.mainnet();

final Uri devDocumentationUri = Uri.parse('https://github.com/blangel/leafy/blob/main/README.md');
Future<void> launchDocumentation() async {
  if (!await launchUrl(devDocumentationUri)) {
    throw Exception('Could not launch $devDocumentationUri');
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
  return _buildScaffold(context, title, body, false, false);
}

Scaffold buildHomeScaffoldWithRestore(BuildContext context, String title, Widget body) {
  return _buildScaffold(context, title, body, false, true);
}

Scaffold buildScaffold(BuildContext context, String title, Widget body) {
  return _buildScaffold(context, title, body, true, false);
}

Scaffold _buildScaffold(BuildContext context, String title, Widget body, bool addLeading, bool addRecovery) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(title),
      actions: addRecovery ? [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String value) {
            if (value == 'recovery') {
              Navigator.pushNamed(context, '/social-recovery', arguments: SocialRecoveryArguments(type: SocialRecoveryType.branch, remoteAccountId: globalRemoteAccountId));
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

  KeyArguments({required this.firstMnemonic, required this.secondDescriptor, required this.secondMnemonic});
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
  branch, setup, setupCompanion, recovery, recoveryCompanion;
}

class SocialRecoveryArguments {
  final SocialRecoveryType type;
  final String remoteAccountId;
  final String? assistingWithCompanionId;

  SocialRecoveryArguments({required this.type, required this.remoteAccountId, this.assistingWithCompanionId});
}

// TODO - update to use biometric_storage (https://pub.dev/packages/biometric_storage) instead of flutter_secure_storage ?

Future<void> persistLocallyViaBiometric(String firstMnemonic, String secondDescriptor, String remoteAccountId) async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  storage.write(key: 'leafy:firstMnemonic', value: firstMnemonic);
  storage.write(key: 'leafy:secondDescriptor', value: secondDescriptor);
  storage.write(key: 'leafy:remoteAccountId', value: remoteAccountId);
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

Future<List<String>> getCompanionIds() async {
  // TODO - pull from local but need to think of place to sync between local and remote
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  var keyPrefix = 'leafy:companion:';
  var all = await storage.readAll();
  return all.keys
      .where((element) => element.startsWith(keyPrefix))
      .map((element) => element.substring(keyPrefix.length)).toList();
}

Future<String> getRecoveryWalletSerialized() async {
  RecoveryWallet? wallet = await getRecoveryWalletViaBiometric();
  if (wallet == null) {
    throw Exception("no wallet found");
  }
  return jsonEncode(wallet.toJson());
}

Future<String> getRecoveryWalletSerializedForCompanion() async {
  RecoveryWallet? wallet = await getRecoveryWalletViaBiometric();
  if (wallet == null) {
    throw Exception("no wallet found");
  }
  // TODO - encrypt with passphrase if present
  var walletSerialized = jsonEncode(wallet.toJson());
  CompanionRecoveryWalletWrapper wrapper = CompanionRecoveryWalletWrapper(companionId: wallet.remoteAccountId, serializedWallet: walletSerialized);
  return jsonEncode(wrapper.toJson());
}

Future<String?> getCompanionIdWalletSerialized(String companionId) async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  String? walletSerialized = await storage.read(key: 'leafy:companion:$companionId');
  if (walletSerialized == null) {
    return null;
  }
  CompanionRecoveryWalletWrapper wrapper = CompanionRecoveryWalletWrapper(companionId: companionId, serializedWallet: walletSerialized);
  return jsonEncode(wrapper.toJson());
}

Future<void> persistCompanionLocallyViaBiometric(String serialized, String companionId) async {
  // TODO - store remotely as well
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));
  storage.write(key: 'leafy:companion:$companionId', value: serialized);
}