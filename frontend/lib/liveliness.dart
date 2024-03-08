import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/transaction.dart';
import 'package:leafy/widget/recovery_utxo.dart';

class LivelinessPage extends StatefulWidget {

  const LivelinessPage({super.key});

  @override
  State<LivelinessPage> createState() => _LivelinessState();

}

class _LivelinessState extends State<LivelinessPage> {

  final AssetImage _livelinessImage = const AssetImage('images/liveliness.gif');

  bool _updateAll = true;
  bool _signing = false;

  @override
  Widget build(BuildContext context) {
    TransactionsArguments arguments = ModalRoute.of(context)!.settings.arguments as TransactionsArguments;
    String remoteAccountLabel = "Remote Account";
    if (arguments.keyArguments.remoteProvider != null) {
      remoteAccountLabel = arguments.keyArguments.remoteProvider!.getDisplayName();
    }
    List<Transaction> livelinessTxs = [];
    livelinessTxs.addAll(arguments.transactions);
    List<Transaction> excludedTxs = [];
    excludedTxs.addAll(arguments.transactions);
    const double sharedMaxHeight = 200;
    if (!_updateAll) {
      livelinessTxs = livelinessTxs.where((tx) => tx.status.confirmed && tx.needLivelinessCheck(arguments.currentBlockHeight + livelinessUpdateThreshold)).toList();
      excludedTxs = excludedTxs.where((tx) => !tx.status.confirmed || !tx.needLivelinessCheck(arguments.currentBlockHeight + livelinessUpdateThreshold)).toList();
    } else {
      livelinessTxs = livelinessTxs.where((tx) => tx.status.confirmed).toList();
      excludedTxs = excludedTxs.where((tx) => !tx.status.confirmed).toList();
    }
    livelinessTxs.sort((a, b) => b.compareTo(a));
    excludedTxs.sort((a, b) => b.compareTo(a));
    List<Utxo> utxos = getUtxos(livelinessTxs);
    List<Utxo> excludedUtxos = getUtxos(excludedTxs);
    return buildScaffold(context, "Liveliness Updates", Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Center(child: Image(height: 150, image: _livelinessImage))),
        Padding(padding: const EdgeInsets.all(10), child: Text("Liveliness updates are like a health check for your wallet. They ensure your bitcoin is kept secure and accessible even in the event you lose access to your $remoteAccountLabel.")),
        Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20),
        Expanded(flex: 1, child: Column(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (utxos.isEmpty)
            ...[
              const Padding(padding: EdgeInsets.all(10), child: Text("No liveliness updates needed at this time.")),
            ]
          else
            ...[
              const Padding(padding: EdgeInsets.all(10), child: Text("Updates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              Flexible(child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: sharedMaxHeight,
                ),
                child: ListView(shrinkWrap: true, children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: utxos.length,
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: InkWell(onTap: null, child: RecoveryUtxoRowWidget(utxo: utxos[index], currentBlockHeight: arguments.currentBlockHeight, strict: false,)));
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20);
                    }
                  )]
              ))),
            ],
            if (excludedUtxos.isNotEmpty)
              ...[
                const Padding(padding: EdgeInsets.all(10), child: Text("Excluded", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                Flexible(child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: sharedMaxHeight,
                  ),
                  child: ListView(shrinkWrap: true, children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: excludedUtxos.length,
                      itemBuilder: (context, index) {
                        return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: InkWell(onTap: null, child: RecoveryUtxoRowWidget(utxo: excludedUtxos[index], currentBlockHeight: arguments.currentBlockHeight, strict: false,)));
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20);
                      }
                    ),
                ]))),
              ],
            ])),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 350, child: Text("Update all confirmed transactions, even those not yet required. This can make liveliness updates more efficient by batching them."))),
                Switch(
                  value: _updateAll,
                  onChanged: _signing ? null : (bool value) {
                    setState(() {
                      _updateAll = value;
                    });
                  },
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Visibility(
                  visible: !_signing && utxos.isNotEmpty,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        _signing = true;
                      });
                      _createAndSignTransaction(context, utxos, arguments.changeAddress, arguments.keyArguments);
                    },
                    label: const Text('Approve Update'),
                    icon: const Icon(Icons.chevron_right),
                  ),
              )),
            )
        ]));
  }

  void _createAndSignTransaction(BuildContext context, List<Utxo> utxos, String destAddr, KeyArguments keyArguments) async {
    const spendAll = 0;
    bitcoinClient.getRecommendedFees().then((fees) {
      // use RecommendedFeeRateLevel.minimum always as normal course is to
      // update 30 days prior to expiry. User always has the option to RBF tx.
      var feeRate = fees.getRate(RecommendedFeeRateLevel.minimum).toDouble();
      createTransaction(utxos, destAddr, destAddr, spendAll, feeRate).then((created) {
        if (created.insufficientFunds) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient fees currently, try again later.', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
            setState(() {
              _signing = false;
            });
          }
          return;
        }
        signTransaction(keyArguments.firstMnemonic, keyArguments.secondMnemonic!, utxos, destAddr, destAddr, spendAll, feeRate).then((signed) async {
          try {
            String txId = await bitcoinClient.submitTransaction(signed);
            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submitted $txId', overflow: TextOverflow.ellipsis), showCloseIcon: true));
              Navigator.of(context).popUntil(ModalRoute.withName('/wallet'));
            }
          } on Exception catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit liveliness update: ${e.toString()}', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
              setState(() {
                _signing = false;
              });
            }
          }
        });
      });
    });
  }

}