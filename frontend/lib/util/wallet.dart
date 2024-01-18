
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

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

String? decryptSecondSeedMnemonic(String firstSeedMnemonic, String encryptedSecondSeedMnemonic) {
  List<int> firstMnemonicBytes = utf8.encode(firstSeedMnemonic);
  Digest firstMnemonicSha = sha256.convert(firstMnemonicBytes);
  final encryptionKey = encrypt.Key.fromBase64(base64Url.encode(firstMnemonicSha.bytes));
  final fernet = encrypt.Fernet(encryptionKey);
  final encrypter = encrypt.Encrypter(fernet);
  try {
    final decrypted = encrypter.decrypt64(encryptedSecondSeedMnemonic);
    var split = decrypted.split(' ');
    if (split.length == 24) {
      return decrypted;
    }
    log("invalid decrypted second mnemonic (length of ${split.length})");
  } catch (e) {
    log("failed to decrypt: ${e.toString()}");
  }
  return null;
}

String encryptSecondSeed(String firstSeedMnemonic, String secondSeedMnemonic) {
  List<int> firstMnemonicBytes = utf8.encode(firstSeedMnemonic);
  Digest firstMnemonicSha = sha256.convert(firstMnemonicBytes);
  final encryptionKey = encrypt.Key.fromBase64(base64Url.encode(firstMnemonicSha.bytes));
  final fernet = encrypt.Fernet(encryptionKey);
  final encrypter = encrypt.Encrypter(fernet);
  return encrypter.encrypt(secondSeedMnemonic).base64;
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