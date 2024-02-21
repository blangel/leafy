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

class _LeafyWalletState extends State<LeafyWalletPage> with RouteAware {

  final AssetImage _walletImage = const AssetImage('images/bitcoin_wallet.gif');

  bool _loadingAddresses = true;
  bool _finishedAddressPaging = false;
  late DataLoader _loader;

  String _receiveAddress = "";
  late List<AddressInfo> _addressInfos;
  late Map<String, List<Transaction>> _transactionsByAddress;
  late List<Transaction> _transactions;

  double _confirmedBitcoin = 0;

  double _unconfirmedBitcoin = 0;

  double _usdPrice = 0;
  int _currentBlockHeight = 0;

  @override
  void initState() {
    super.initState();
    _addressInfos = [];
    _transactionsByAddress = {};
    _transactions = [];
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
    _loader.init(keyArguments.firstMnemonic, keyArguments.secondDescriptor, _handleDataLoad);
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
            !_finishedAddressPaging ?
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
                AutoSizeText("${formatBitcoin(_confirmedBitcoin + _unconfirmedBitcoin)} ₿", style: const TextStyle(fontSize: 40), textAlign: TextAlign.end, minFontSize: 20, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis),
                if (_unconfirmedBitcoin != 0)
                  ...[
                    AutoSizeText("of which ${formatBitcoin(_unconfirmedBitcoin)} ₿ is pending", textAlign: TextAlign.end, minFontSize: 10, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis)
                  ],
                if (_usdPrice != 0)
                  ...[
                    AutoSizeText(formatCurrency((_confirmedBitcoin + _unconfirmedBitcoin) * _usdPrice), style: const TextStyle(fontSize: 20, color: Colors.greenAccent), textAlign: TextAlign.end, minFontSize: 10, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis),
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
                      Navigator.pushNamed(context, '/liveliness', arguments: TransactionsArguments(keyArguments: keyArguments, transactions: _transactions, changeAddress: _receiveAddress, currentBlockHeight: _currentBlockHeight));
                    },
                    label: Text("Review Update${livelinessTransactions > 1 ? 's' : ''}", style: const TextStyle(fontSize: 14)))
                )
              ],
            ))
          ],
        Expanded(flex: 1, child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(10), child: Text("Recent Transactions", style: TextStyle(fontSize: 24), textAlign: TextAlign.start)),
          if (_loadingAddresses)
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
            if (_transactions.isEmpty)
              ...[const Padding(padding: EdgeInsets.all(10), child: Text("No transactions"))]
            else
              ...[
                ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: min(5, _transactions.length),
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: InkWell(onTap: () {
                            Navigator.pushNamed(context, '/transaction',
                                arguments: TransactionArgument(keyArguments: keyArguments, transaction: _transactions[index], transactions: _transactions, changeAddress: _receiveAddress, currentBlockHeight: _currentBlockHeight));
                          }, child: TransactionRowWidget(transaction: _transactions[index], currentBlockHeight: _currentBlockHeight)));
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
                          arguments: TransactionsArguments(keyArguments: keyArguments, transactions: _transactions, changeAddress: _receiveAddress, currentBlockHeight: _currentBlockHeight));
                    }, child: const Text("see all transactions", style: TextStyle(decoration: TextDecoration.underline),)),
                    TextButton(onPressed: () {
                      Navigator.pushNamed(context, '/addresses',
                          arguments: AddressArguments(keyArguments: keyArguments, addresses: _addressInfos, transactions: _transactionsByAddress, allTransactions: _transactions, changeAddress: _receiveAddress, currentBlockHeight: _currentBlockHeight));
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
                  onPressed: _receiveAddress.isEmpty ? null : () {
                    Navigator.pushNamed(context, '/receive-address',
                        arguments: AddressArgument(keyArguments: keyArguments, address: _receiveAddress, transactions: _transactions, changeAddress: _receiveAddress));
                  },
                  label: const Text("Receive", style: TextStyle(fontSize: 24),)),
              const SizedBox(width: 10),
              TextButton.icon(icon: const Icon(Icons.send),
                  onPressed: _addressInfos.isEmpty || _receiveAddress.isEmpty ? null : () {
                    Navigator.pushNamed(context, '/create-transaction', arguments: CreateTransactionArguments(keyArguments: keyArguments, transactions: _transactions, changeAddress: _receiveAddress));
                  }, label: const Text("Send", style: TextStyle(fontSize: 24))),
            ],
          )
        ]))
      ],
    ));
  }

  @override
  void didPopNext() {
    _loader.forceLoad(_handleDataLoad);
  }

  void _handleDataLoad(List<String> addresses, AddressMetadata? metadata, bool paging, double usdPrice, int currentBlockHeight) {
    if (!context.mounted) {
      return;
    }
    setState(() {
      if (metadata != null) {
        _confirmedBitcoin = metadata.confirmedBitcoin;
        _unconfirmedBitcoin = metadata.unconfirmedBitcoin;
        _addressInfos = metadata.addressInfos;
        _transactionsByAddress = metadata.transactionsByAddress;
        _transactions = metadata.transactions;
        _receiveAddress = metadata.receiveAddress;
      }
      _usdPrice = usdPrice;
      _currentBlockHeight = currentBlockHeight;
      _finishedAddressPaging = !paging;
      _loadingAddresses = false;
    });
  }

  bool _needLivelinessCheck() {
    if (_loadingAddresses) {
      return false;
    }
    return _transactions.any((tx) => tx.needLivelinessCheck(_currentBlockHeight + livelinessUpdateThreshold));
  }

  int _numberOfLivelinessChecksNeeded() {
    if (_loadingAddresses) {
      return 0;
    }
    return _transactions.fold(0, (previousValue, tx) => tx.needLivelinessCheck(_currentBlockHeight + livelinessUpdateThreshold) ? previousValue + 1 : previousValue);
  }
}