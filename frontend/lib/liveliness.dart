import 'dart:developer';

import 'package:flutter/foundation.dart';
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

  @override
  Widget build(BuildContext context) {
    TransactionsArguments arguments = ModalRoute.of(context)!.settings.arguments as TransactionsArguments;
    List<Transaction> copiedTxs = [];
    copiedTxs.addAll(arguments.transactions);
    copiedTxs.sort((a, b) => b.compareTo(a));
    List<Utxo> utxos = getUtxos(copiedTxs);
    return buildScaffold(context, "Liveliness Updates", Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Center(child: Image(height: 150, image: _livelinessImage))),
        const Padding(padding: EdgeInsets.all(10), child: Text("Liveliness updates ensure your bitcoin is kept secure and accessible even in the case you loss access to your Remote Account. It is like a health check for your wallet.")),
        Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20),
          if (!_needLivelinessUpdates(utxos, arguments.currentBlockHeight))
            ...[
              Padding(padding: const EdgeInsets.all(10), child: Text("No liveliness updates needed at this time.${utxos.isNotEmpty ? ' Next liveliness update needed in ${_getEarliestLivelinessUpdateDesc(utxos, arguments.currentBlockHeight)}.' : ''}")),
            ]
          else
            ...[
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
              ),
            ],
        ]));
  }

  bool _needLivelinessUpdates(List<Utxo> utxos, int currentBlockHeight) {
    return utxos.any((utxo) => utxo.status.needLivelinessCheck(currentBlockHeight + livelinessUpdateThreshold));
  }

  String _getEarliestLivelinessUpdateDesc(List<Utxo> utxos, int currentBlockHeight) {
    List<int> blocksUntilLiveliness = utxos.map((utxo) => utxo.status.blocksToLiveliness(currentBlockHeight + livelinessUpdateThreshold)).toList();
    mergeSort(blocksUntilLiveliness);
    return blocksToDurationFormatted(blocksUntilLiveliness[0]);
  }

}