
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/price_service.dart';
import 'package:synchronized/synchronized.dart';

import 'package:leafy/util/wallet.dart';

class AddressMetadata {
  final double confirmedBitcoin;
  final double unconfirmedBitcoin;
  final List<AddressInfo> addressInfos;
  final Map<String, List<Transaction>> transactionsByAddress;
  final List<Transaction> transactions;
  final String receiveAddress;

  AddressMetadata(
      this.confirmedBitcoin,
      this.unconfirmedBitcoin,
      this.addressInfos,
      this.transactionsByAddress,
      this.transactions,
      this.receiveAddress);
}

class DataLoader {

  static const int _loadAmount = 5;

  static const int _addressWithoutTransactionStopAmount = 3;

  final List<String> _addresses = [];

  final _lock = Lock();
  bool _init = false;

  late String _firstSeedMnemonic;
  late String _secondSeedDescriptor;

  late Timer _timer; // TODO - use websockets instead (need support from bitcoinClient implementation)

  int _startIndex;
  bool _continuePaging = true;
  bool _loadingAddressInfos = false;

  double _usdPrice = 0.0;

  int _currentBlockHeight = 0;

  DataLoader({startIndex = 0}) : _startIndex = startIndex;

  Future<void> init(String firstSeedMnemonic, String secondSeedDescriptor, void Function(List<String>, AddressMetadata?, bool, double, int) callback) async {
    await _lock.synchronized(() {
      if (_init) {
        return;
      }
      _init = true;
      _firstSeedMnemonic = firstSeedMnemonic;
      _secondSeedDescriptor = secondSeedDescriptor;
      _timer = Timer.periodic(const Duration(seconds: 10), (Timer t) {
        _load(callback);
      });
      _loadAddresses(callback);
    });
  }

  void dispose() {
    _timer.cancel();
  }

  void forceLoad(void Function(List<String>, AddressMetadata?, bool, double, int) callback) async {
    _load(callback);
  }

  void _load(void Function(List<String>, AddressMetadata?, bool, double, int) callback) async {
    _loadPriceData();
    _loadBlockHeight();
    _loadAddressInfoForAddresses(callback);
  }

  void _loadPriceData() async {
    var rnd = Random();
    if (rnd.nextBool()) {
      _usdPrice = await priceService.getCurrentPrice(Currency.usd);
    }
  }

  void _loadBlockHeight() async {
    bitcoinClient.getCurrentBlockHeight().then((height) {
      _currentBlockHeight = height;
    });
  }

  void _loadAddresses(void Function(List<String>, AddressMetadata?, bool, double, int) callback) {
    developer.log("loading addresses: [$_startIndex, ${_startIndex + _loadAmount})");
    getAddresses(_firstSeedMnemonic, _secondSeedDescriptor, _startIndex, _loadAmount).then((addresses) async {
      List<String> allAddresses = [];
      allAddresses.addAll(_addresses);
      allAddresses.addAll(addresses);
      _startIndex += _loadAmount;
      _addresses.clear();
      _addresses.addAll(allAddresses);
      _loadAddressInfoForAddresses(callback);
      _loadPriceData();
      _loadBlockHeight();
    });
  }

  Future<void> _loadAddressInfoForAddresses(void Function(List<String>, AddressMetadata?, bool, double, int) callback) async {
    if (_addresses.isEmpty) {
      callback(_addresses, null, _continuePaging, _usdPrice, _currentBlockHeight);
      return;
    }
    if (_loadingAddressInfos) {
      return;
    }
    _loadingAddressInfos = true;
    double confirmedSats = 0;
    double unconfirmedSats = 0;
    List<AddressInfo> addressInfos = [];
    Set<Transaction> allTransactions = {};
    String addressWithoutTransactions = "";
    int addressWithoutTransactionsCount = 0;
    Map<String, List<Transaction>> transactionsByAddress = {};
    List<String> copiedAddresses = [];
    copiedAddresses.addAll(_addresses);
    for (String address in copiedAddresses) {
      AddressInfo info = await bitcoinClient.getAddressInfo(address);
      if (((info.chainStats.transactionCount + info.mempoolStats.transactionCount) == 0)
          && ((info.chainStats.bitcoinSum + info.mempoolStats.bitcoinSum) == 0)) {
        addressWithoutTransactionsCount++;
        if (addressWithoutTransactions.isEmpty) {
          addressWithoutTransactions = info.address;
        }
      } else {
        addressInfos.add(info);
        confirmedSats += (info.chainStats.bitcoinSum - info.chainStats.spentBitcoinSum);
        unconfirmedSats += (info.mempoolStats.bitcoinSum - info.mempoolStats.spentBitcoinSum);
        List<Transaction> addressTransactions = await bitcoinClient.getAddressTransactions(address);
        addressTransactions = addressTransactions.map((item) => item.fromKnownAddresses(copiedAddresses)).toList();
        List<Future<Transaction>> futureTransactions = addressTransactions.map((item) {
          return bitcoinClient.augmentTransactionWithUnspentUtxos(item);
        }).toList();
        addressTransactions = await Future.wait(futureTransactions);
        transactionsByAddress[address] = addressTransactions;
        allTransactions.addAll(addressTransactions);
      }
    }
    List<Transaction> transactionsSorted = allTransactions.toList();
    transactionsSorted.sort();

    if (_continuePaging) {
      // page until at least 3 addresses without txs found; can get
      // sparse addr use via RBF txs (i.e. change addr of tx which is replaced
      // where the replacement tx's change addr is different).
      if (addressWithoutTransactionsCount < _addressWithoutTransactionStopAmount) {
        _loadAddresses(callback);
      } else {
        _continuePaging = false;
      }
    }
    callback(copiedAddresses, AddressMetadata(
        fromSatsToBitcoin(confirmedSats),
        fromSatsToBitcoin(unconfirmedSats),
        addressInfos,
        transactionsByAddress,
        transactionsSorted,
        addressWithoutTransactions), _continuePaging, _usdPrice, _currentBlockHeight);
    _loadingAddressInfos = false;
  }

}