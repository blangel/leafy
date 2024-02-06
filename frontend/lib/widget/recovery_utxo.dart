
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/transaction.dart';

class RecoveryUtxoRowWidget extends StatelessWidget {

  final Utxo _utxo;

  final int _currentBlockHeight;

  final bool _strict;

  const RecoveryUtxoRowWidget({super.key, required Utxo utxo, required int currentBlockHeight, required bool strict}) :
    _utxo = utxo,
    _currentBlockHeight = currentBlockHeight,
    _strict = strict;

  @override
  Widget build(BuildContext context) {
    double netBitcoin = fromSatsToBitcoin(_utxo.amount.toDouble());
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 175, child: Text(_utxo.getDateTime(), style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 5,),
        if (!_utxo.status.needLivelinessCheck(_strict ? _currentBlockHeight : _currentBlockHeight + livelinessUpdateThreshold))
          ...[
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.yellowAccent,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text('recover in ${_utxo.status.getDurationUntil(_strict ? _currentBlockHeight : _currentBlockHeight + livelinessUpdateThreshold)}', style: const TextStyle(fontSize: 10, color: Colors.black87))
            )
          ]
        else
          ...[
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Text('recover now', style: TextStyle(fontSize: 10, color: Colors.black87))
            )
          ],
        Expanded(flex: 1, child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 50, child: AutoSizeText("${formatBitcoin(netBitcoin)} ₿", style: const TextStyle(fontSize: 20), textAlign: TextAlign.end, minFontSize: 14, stepGranularity: 1, maxLines: 1, overflow: TextOverflow.ellipsis,)),
          ],
        ))
      ],
    );
  }

}