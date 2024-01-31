import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/price_service.dart';
import 'package:leafy/widget/transaction.dart';
import 'package:shimmer/shimmer.dart';

class LeafyWalletPage extends StatefulWidget {

  const LeafyWalletPage({super.key});

  @override
  State<LeafyWalletPage> createState() => _LeafyWalletState();

}

class _LeafyWalletState extends State<LeafyWalletPage> {

  final AssetImage _walletImage = const AssetImage('images/bitcoin_wallet.gif');

  bool loadingAddresses = true;
  bool loadingAddressInfo = false;
  bool finishedAddressPaging = false;
  late List<String> addresses;
  String receiveAddress = "";
  late List<AddressInfo> addressInfos;
  late Map<String, List<Transaction>> transactionsByAddress;
  late List<Transaction> transactions;

  // TODO - use websockets instead (need support from bitcoinClient implementation)
  Timer? timer;

  double confirmedBitcoin = 0;

  double unconfirmedBitcoin = 0;

  int startIndex = 0;

  double usdPrice = 0;

  @override
  void initState() {
    super.initState();
    addresses = [];
    addressInfos = [];
    transactionsByAddress = {};
    transactions = [];
    setupRefreshTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void setupRefreshTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 10), (Timer t) => {
      if (addresses.isNotEmpty) {
        loadAddressInfo()
      },
      _loadPriceData()
    });
  }

  void _loadPriceData() async {
    var rnd = Random();
    if (rnd.nextBool()) {
      usdPrice = await priceService.getCurrentPrice(Currency.usd);
    }
  }

  void _loadAddresses(BuildContext context) async {
    final keyArguments = ModalRoute.of(context)!.settings.arguments as KeyArguments;
    int num = 5;
    developer.log("loading addresses: [$startIndex, ${startIndex + num})");
    getAddresses(keyArguments.firstMnemonic, keyArguments.secondDescriptor, startIndex, num).then((addresses) async {
      List<String> allAddresses = [];
      allAddresses.addAll(this.addresses);
      allAddresses.addAll(addresses);

      setState(() {
        this.addresses = allAddresses;
        startIndex += num;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      _loadAddresses(context);
    }
    KeyArguments keyArguments = ModalRoute.of(context)!.settings.arguments as KeyArguments;
    return buildHomeScaffoldWithRestore(context, '🌿 Wallet', keyArguments.walletPassword, keyArguments.firstMnemonic, Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 0), child:
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 1, child: Image(height: 150, image: _walletImage, alignment: Alignment.centerLeft)),
            Expanded(flex: 2, child:
            !finishedAddressPaging ?
            Shimmer.fromColors(
                baseColor: Colors.black12,
                highlightColor: Colors.white70,
                enabled: true,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(
                  width: 100.0,
                  height: 10.0,
                  color: Colors.white,
                ))
            )
                :
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AutoSizeText("${formatBitcoin(confirmedBitcoin + unconfirmedBitcoin)} ₿", style: const TextStyle(fontSize: 40), textAlign: TextAlign.end, minFontSize: 20, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis),
                if (unconfirmedBitcoin != 0)
                  ...[
                    AutoSizeText("of which ${formatBitcoin(unconfirmedBitcoin)} ₿ is pending", textAlign: TextAlign.end, minFontSize: 10, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis)
                  ],
                if (usdPrice != 0)
                  ...[
                    AutoSizeText(formatCurrency((confirmedBitcoin + unconfirmedBitcoin) * usdPrice), style: const TextStyle(fontSize: 20, color: Colors.greenAccent), textAlign: TextAlign.end, minFontSize: 10, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis),
                  ],
              ],
            )
            ),
          ],
        )
        ),
        Expanded(flex: 1, child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(10), child: Text("Recent Transactions", style: TextStyle(fontSize: 24), textAlign: TextAlign.start)),
          if (loadingAddresses)
            ...[Shimmer.fromColors(
                baseColor: Colors.black12,
                highlightColor: Colors.white70,
                enabled: true,
                child: Padding(padding: const EdgeInsets.all(10), child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 10.0,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10,),
                    Container(
                      height: 10.0,
                      color: Colors.white,
                    )
                  ],
                ))
            )]
          else
            if (transactions.isEmpty)
              ...[const Padding(padding: EdgeInsets.all(10), child: Text("No transactions"))]
            else
              ...[
                ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: min(5, transactions.length),
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: InkWell(onTap: () {
                            Navigator.pushNamed(context, '/transaction',
                                arguments: TransactionArgument(keyArguments: keyArguments, transaction: transactions[index], transactions: transactions, changeAddress: receiveAddress));
                          }, child: TransactionRowWidget(transaction: transactions[index])));
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20);
                    }
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextButton(onPressed: () {
                      Navigator.pushNamed(context, '/transactions',
                          arguments: TransactionsArguments(keyArguments: keyArguments, transactions: transactions, changeAddress: receiveAddress));
                    }, child: const Text("see all transactions", style: TextStyle(decoration: TextDecoration.underline),)),
                    TextButton(onPressed: () {
                      Navigator.pushNamed(context, '/addresses',
                          arguments: AddressArguments(keyArguments: keyArguments, addresses: addressInfos, transactions: transactionsByAddress, allTransactions: transactions, changeAddress: receiveAddress));
                    }, child: const Text("see all addresses", style: TextStyle(decoration: TextDecoration.underline))),
                  ],
                )
              ],
          Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextButton.icon(icon: const Icon(Icons.arrow_downward),
                  onPressed: receiveAddress.isEmpty ? null : () {
                    Navigator.pushNamed(context, '/receive-address',
                        arguments: AddressArgument(keyArguments: keyArguments, address: receiveAddress, transactions: transactions, changeAddress: receiveAddress));
                  },
                  label: const Text("Receive", style: TextStyle(fontSize: 24),)),
              const SizedBox(width: 10),
              TextButton.icon(icon: const Icon(Icons.send),
                  onPressed: addressInfos.isEmpty || receiveAddress.isEmpty ? null : () {
                    Navigator.pushNamed(context, '/create-transaction', arguments: CreateTransactionArguments(keyArguments: keyArguments, transactions: transactions, changeAddress: receiveAddress));
                  }, label: const Text("Send", style: TextStyle(fontSize: 24))),
            ],
          )
        ]))
      ],
    ));
  }

  Future<List<String>> getAddresses(String firstMnemonic, String secondDescriptor, int startIndex, int num) async {
    try {
      final List<dynamic> list = await platform.invokeMethod("getAddresses", <String, dynamic>{
        'networkName': bitcoinClient.getBitcoinNetworkName(),
        'firstMnemonic': firstMnemonic,
        'secondDescriptor': secondDescriptor,
        'startIndex': startIndex.toString(),
        'num': num.toString(),
      });
      return list.cast<String>();
    } on PlatformException catch (e) {
      // TODO - handle corruption of mnemonic (often manifests as "PlatformException(GenerateAddresses Failure, Checksum incorrect")
      throw ArgumentError("failed to getAddresses: $e");
    }
  }

  Future<void> loadAddressInfo() async {
    if (!context.mounted) {
      timer?.cancel();
      return;
    }
    if (loadingAddressInfo) {
      return;
    }
    loadingAddressInfo = true;
    double confirmedSats = 0;
    double unconfirmedSats = 0;
    List<AddressInfo> addressInfos = [];
    Set<Transaction> allTransactions = {};
    String addressWithoutTransactions = "";
    int addressWithoutTransactionsCount = 0;
    Map<String, List<Transaction>> transactionsByAddress = {};
    for (String address in addresses) {
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
        addressTransactions = addressTransactions.map((item) => item.fromKnownAddresses(addresses)).toList();
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

    if (context.mounted) {
      // page until at least 3 addresses without txs found; can get
      // sparse addr use via RBF txs (i.e. change addr of tx which is replaced
      // where the replacement tx's change addr is different).
      if (addressWithoutTransactionsCount < 3) {
        _loadAddresses(context);
      } else {
        finishedAddressPaging = true;
      }
      setState(() {
        confirmedBitcoin = fromSatsToBitcoin(confirmedSats);
        unconfirmedBitcoin = fromSatsToBitcoin(unconfirmedSats);
        this.addressInfos = addressInfos;
        this.transactionsByAddress = transactionsByAddress;
        transactions = transactionsSorted;
        receiveAddress = addressWithoutTransactions;
        loadingAddresses = false;
      });
    }
    loadingAddressInfo = false;
  }

}