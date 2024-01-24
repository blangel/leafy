
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

const mnemonicLength = 24;

Future<Wallet> createNewWallet() async {
  try {
    List<int> jsonBytes = await platform.invokeMethod("createNewWallet", <String, dynamic>{
      'networkName': bitcoinClient.getBitcoinNetworkName(),
    });
    Map<String, dynamic> json = jsonDecode(utf8.decode(jsonBytes));
    return Wallet.fromNativeJson(json);
  } on PlatformException catch (e) {
    throw ArgumentError("failed to createNewWallet: $e");
  }
}

bool firstSeedMnemonicNeedsPassword(String firstSeedMnemonic) {
  var split = firstSeedMnemonic.split(' ');
  return split.length != 24;
}

RecoveryWallet? decryptWallet(String password, RecoveryWallet wallet) {
  final firstMnemonic = decryptLeafyData(password, wallet.firstMnemonic, mnemonicLength);
  if (firstMnemonic == null) {
    return null;
  }
  final secondDescriptor = decryptLeafyData(password, wallet.secondDescriptor, 1);
  if (secondDescriptor == null) {
    return null;
  }
  final remoteAccountId = decryptLeafyData(password, wallet.remoteAccountId, 1);
  if (remoteAccountId == null) {
    return null;
  }
  return RecoveryWallet(firstMnemonic: firstMnemonic, secondDescriptor: secondDescriptor, remoteAccountId: remoteAccountId);
}

String? decryptLeafyData(String password, String data, int lengthCheck) {
  List<int> passwordBytes = utf8.encode(password);
  Digest passwordSha = sha256.convert(passwordBytes);
  final encryptionKey = encrypt.Key.fromBase64(base64Url.encode(passwordSha.bytes));
  final fernet = encrypt.Fernet(encryptionKey);
  final encrypter = encrypt.Encrypter(fernet);
  try {
    final decrypted = encrypter.decrypt64(data);
    var split = decrypted.split(' ');
    if (split.length == lengthCheck) {
      return decrypted;
    }
    log("invalid decrypted data (length of ${split.length})");
  } catch (e) {
    log("failed to decrypt: ${e.toString()}");
  }
  return null;
}

RecoveryWallet encryptWallet(String? password, RecoveryWallet wallet) {
  if (password == null) {
    return wallet;
  }
  final firstMnemonic = encryptLeafyData(password, wallet.firstMnemonic);
  final secondDescriptor = encryptLeafyData(password, wallet.secondDescriptor);
  final remoteAccountId = encryptLeafyData(password, wallet.remoteAccountId);
  return RecoveryWallet(firstMnemonic: firstMnemonic, secondDescriptor: secondDescriptor, remoteAccountId: remoteAccountId);
}

String encryptLeafyData(String password, String data) {
  List<int> passwordBytes = utf8.encode(password);
  Digest passwordSha = sha256.convert(passwordBytes);
  final encryptionKey = encrypt.Key.fromBase64(base64Url.encode(passwordSha.bytes));
  final fernet = encrypt.Fernet(encryptionKey);
  final encrypter = encrypt.Encrypter(fernet);
  return encrypter.encrypt(data).base64;
}

class Wallet {

  final String firstMnemonic;
  final String secondMnemonic;
  final String secondDescriptor;

  Wallet({required this.firstMnemonic, required this.secondMnemonic, required this.secondDescriptor});

  factory Wallet.fromNativeJson(Map<String, dynamic> json) {
    return Wallet(
      firstMnemonic: json['FirstMnemonic'],
      secondMnemonic: json['SecondMnemonic'],
      secondDescriptor: json['SecondDescriptor'],
    );
  }

}

class RecoveryWallet {
  final String firstMnemonic;
  final String secondDescriptor;
  final String remoteAccountId;

  RecoveryWallet({required this.firstMnemonic, required this.secondDescriptor, required this.remoteAccountId});

  Map<String, dynamic> toJson() {
    return {
      'f': firstMnemonic,
      's': secondDescriptor,
    };
  }

  factory RecoveryWallet.fromJson(String remoteAccountId, Map<String, dynamic> json) {
    return RecoveryWallet(
      firstMnemonic: json['f'],
      secondDescriptor: json['s'],
      remoteAccountId: remoteAccountId,
    );
  }
}

class CompanionRecoveryWalletWrapper {
  final String companionId;
  final String serializedWallet;

  CompanionRecoveryWalletWrapper({required this.companionId, required this.serializedWallet});

  Map<String, dynamic> toJson() {
    return {
      'c': companionId,
      'w': serializedWallet,
    };
  }

  static isCompanionRecoveryWalletWrapper(Map<String, dynamic> json) {
    return json.containsKey('c') && json.containsKey('w');
  }

  factory CompanionRecoveryWalletWrapper.fromJson(Map<String, dynamic> json) {
    return CompanionRecoveryWalletWrapper(
      companionId: json['c'],
      serializedWallet: json['w'],
    );
  }
}