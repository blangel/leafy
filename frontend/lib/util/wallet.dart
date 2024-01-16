
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';

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