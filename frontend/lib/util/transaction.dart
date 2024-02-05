
import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';

class TransactionHex {

  final String hex;
  final int totalInput;
  final int amount;
  final int fees;
  final int change;
  final bool insufficientFunds;
  final bool changeIsDust;

  TransactionHex({required this.hex, required this.totalInput, required this.amount,
    required this.fees, required this.change, this.insufficientFunds = false, this.changeIsDust = false});

  factory TransactionHex.insufficientFunds() {
    return TransactionHex(
      hex: "",
      totalInput: 0,
      amount: 0,
      fees: 0,
      change: 0,
      insufficientFunds: true,
      changeIsDust: false,
    );
  }

  factory TransactionHex.fromNativeJson(Map<String, dynamic> json) {
    return TransactionHex(
      hex: json['Hex'],
      totalInput: json['TotalInput'],
      amount: json['Amount'],
      fees: json['Fees'],
      change: json['Change'],
      changeIsDust: json['ChangeIsDust'],
    );
  }

  TransactionHex withHex(String hex) {
    return TransactionHex(
        hex: hex,
        totalInput: totalInput,
        amount: amount,
        fees: fees,
        change: change,
        changeIsDust: changeIsDust
    );
  }
}

class Outpoint {

  final List<int> hash;
  final int index;

  Outpoint({required this.hash, required this.index});

  Map<String, dynamic> toJson() {
    return {
      'Hash': hash,
      'Index': index,
    };
  }

  static Outpoint fromTxId(String txId, int index) {
    Uint8List inverted = Uint8List.fromList(decodeHexString(txId));
    Uint8List invertedByteArray = _invertEndianness(inverted);
    return Outpoint(hash: invertedByteArray, index: index);
  }

  static Uint8List _invertEndianness(Uint8List byteArray) {
    return Uint8List.fromList(byteArray.reversed.toList());
  }

}

class Utxo {

  final String address;
  final Outpoint outpoint;
  final int amount;
  final String script;
  final TransactionStatus status;

  Utxo({required this.address, required this.outpoint, required this.amount,
    required this.script, required this.status});

  String getDateTime() {
    return getDateTimeFromBlockTime(status.blockTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'FromAddress': address,
      'Outpoint': outpoint.toJson(),
      'Amount': amount,
      'Script': script,
    };
  }
}

List<Utxo> getUtxos(List<Transaction> transactions) {
  return transactions.map((tx) =>
      tx.vouts.where((vout) => vout.unspent && vout.toKnownAddress).map((vout) => Utxo(address: vout.scriptPubkeyAddress, outpoint: Outpoint.fromTxId(tx.id, vout.index), amount: vout.valueSat, script: vout.scriptPubkey, status: tx.status))
  ).expand((utxo) => utxo).toList();
}

Future<TransactionHex> createTransaction(List<Utxo> utxos, String changeAddress, String destinationAddress, int amount, double feeRate) async {
  try {
    List<int> jsonBytes = await platform.invokeMethod("createTransaction", <String, dynamic>{
      'networkName': bitcoinClient.getBitcoinNetworkName(),
      'utxos': jsonEncode(utxos.map((utxo) => utxo.toJson()).toList()),
      'changeAddress': changeAddress,
      'destinationAddress': destinationAddress,
      'amount': amount.toString(),
      'feeRate': feeRate.toString(),
    });
    Map<String, dynamic> json = jsonDecode(utf8.decode(jsonBytes));
    return TransactionHex.fromNativeJson(json);
  } on PlatformException catch (e) {
    if ((e.message != null) && e.message!.contains("insufficient funds")) {
      return TransactionHex.insufficientFunds();
    }
    throw ArgumentError("failed to createTransaction: $e");
  }
}

Future<String> signTransaction(String firstMnemonic, String secondMnemonic, List<Utxo> utxos, String changeAddress, String destinationAddress, int amount, double feeRate) async {
  try {
    List<int> jsonBytes = await platform.invokeMethod("createAndSignTransaction", <String, dynamic>{
      'networkName': bitcoinClient.getBitcoinNetworkName(),
      'firstMnemonic': firstMnemonic,
      'secondMnemonic': secondMnemonic,
      'utxos': jsonEncode(utxos.map((utxo) => utxo.toJson()).toList()),
      'changeAddress': changeAddress,
      'destinationAddress': destinationAddress,
      'amount': amount.toString(),
      'feeRate': feeRate.toString(),
    });
    Map<String, dynamic> json = jsonDecode(utf8.decode(jsonBytes));
    return json['Hex'];
  } on PlatformException catch (e) {
    throw ArgumentError("failed to signTransaction: $e");
  }
}