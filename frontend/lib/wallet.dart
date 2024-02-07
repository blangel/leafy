import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/data_loader.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
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
  bool finishedAddressPaging = false;
  late DataLoader _loader;

  late List<String> addresses;
  String receiveAddress = "";
  late List<AddressInfo> addressInfos;
  late Map<String, List<Transaction>> transactionsByAddress;
  late List<Transaction> transactions;

  double confirmedBitcoin = 0;

  double unconfirmedBitcoin = 0;

  double usdPrice = 0;
  int currentBlockHeight = 0;

  @override
  void initState() {
    super.initState();
    addresses = [];
    addressInfos = [];
    transactionsByAddress = {};
    transactions = [];
    _loader = DataLoader();
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    KeyArguments keyArguments = ModalRoute.of(context)!.settings.arguments as KeyArguments;
    _loader.init(keyArguments.firstMnemonic, keyArguments.secondDescriptor, (addresses, metadata, paging, usdPrice, currentBlockHeight) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        this.addresses = addresses;
        if (metadata != null) {
          confirmedBitcoin = metadata.confirmedBitcoin;
          unconfirmedBitcoin = metadata.unconfirmedBitcoin;
          addressInfos = metadata.addressInfos;
          transactionsByAddress = metadata.transactionsByAddress;
          transactions = metadata.transactions;
          receiveAddress = metadata.receiveAddress;
        }
        this.usdPrice = usdPrice;
        this.currentBlockHeight = currentBlockHeight;
        finishedAddressPaging = !paging;
        loadingAddresses = false;
      });
    });
    var livelinessTransactions = _numberOfLivelinessChecksNeeded();
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
        if (_needLivelinessCheck())
          ...[
            Padding(padding: const EdgeInsets.all(10), child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Liveliness Updates", style: TextStyle(fontSize: 24), textAlign: TextAlign.start),
                Text("$livelinessTransactions transaction${livelinessTransactions > 1 ? 's' : ''} require${livelinessTransactions > 1 ? '' : 's'} a liveliness update."),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.monitor_heart_outlined),
                    onPressed: () {
                      Navigator.pushNamed(context, '/liveliness', arguments: TransactionsArguments(keyArguments: keyArguments, transactions: transactions, changeAddress: receiveAddress, currentBlockHeight: currentBlockHeight));
                    },
                    label: Text("Perform Update${livelinessTransactions > 1 ? 's' : ''}", style: const TextStyle(fontSize: 14)))
                )
              ],
            ))
          ],
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
                                arguments: TransactionArgument(keyArguments: keyArguments, transaction: transactions[index], transactions: transactions, changeAddress: receiveAddress, currentBlockHeight: currentBlockHeight));
                          }, child: TransactionRowWidget(transaction: transactions[index], currentBlockHeight: currentBlockHeight)));
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
                          arguments: TransactionsArguments(keyArguments: keyArguments, transactions: transactions, changeAddress: receiveAddress, currentBlockHeight: currentBlockHeight));
                    }, child: const Text("see all transactions", style: TextStyle(decoration: TextDecoration.underline),)),
                    TextButton(onPressed: () {
                      Navigator.pushNamed(context, '/addresses',
                          arguments: AddressArguments(keyArguments: keyArguments, addresses: addressInfos, transactions: transactionsByAddress, allTransactions: transactions, changeAddress: receiveAddress, currentBlockHeight: currentBlockHeight));
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

  bool _needLivelinessCheck() {
    if (loadingAddresses) {
      return false;
    }
    return transactions.any((tx) => tx.needLivelinessCheck(currentBlockHeight + livelinessUpdateThreshold));
  }

  int _numberOfLivelinessChecksNeeded() {
    if (loadingAddresses) {
      return 0;
    }
    return transactions.fold(0, (previousValue, tx) => tx.needLivelinessCheck(currentBlockHeight + livelinessUpdateThreshold) ? previousValue + 1 : previousValue);
  }
}