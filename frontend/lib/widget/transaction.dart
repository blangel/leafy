
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';

class TransactionRowWidget extends StatelessWidget {

  final Transaction transaction;

  final int currentBlockHeight;

  const TransactionRowWidget({super.key, required this.transaction, required this.currentBlockHeight});

  @override
  Widget build(BuildContext context) {
    double netBitcoin = fromSatsToBitcoin(((transaction.incoming??0) - (transaction.outgoing??0)).toDouble());
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 135, child: Text(shortTransactionId(transaction.id), style: const TextStyle(fontSize: 18))),
        const SizedBox(width: 5,),
        if (!transaction.status.confirmed)
          ...[
            Padding(padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Text('unconfirmed'))),
          ]
        else if (transaction.needLivelinessCheck(currentBlockHeight + livelinessUpdateThreshold))
          ...[
            Padding(padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                child: Column(
                  children: [
                    Text(transaction.status.getDateTime(), style: const TextStyle(fontSize: 10)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: transaction.needLivelinessCheck(currentBlockHeight) ? Colors.redAccent : Colors.greenAccent,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(transaction.needLivelinessCheck(currentBlockHeight) ? 'liveliness past due' : 'liveliness available', style: const TextStyle(fontSize: 10, color: Colors.black87)))
                  ],
                )
            )
          ]
        else
          ...[
            Text(transaction.status.getDateTime(), style: const TextStyle(fontSize: 10)),
          ],
        Expanded(flex: 1, child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 125, child: AutoSizeText("${formatBitcoin(netBitcoin)} ₿", style: const TextStyle(fontSize: 20), textAlign: TextAlign.end, minFontSize: 14, stepGranularity: 1, maxLines: 1, overflow: TextOverflow.ellipsis,)),
            const SizedBox(width: 5),
            if (netBitcoin < 0)
              ...[
                const Icon(Icons.call_made, color: Colors.redAccent, size: 10,),
              ]
            else
              ...[
                if (netBitcoin > 0)
                  ...[
                    const Icon(Icons.call_received, color: Colors.greenAccent, size: 10,),
                  ]
                else
                  ...[],
              ],
          ],
        ))
      ],
    );
  }

}

String shortTransactionId(String id) {
  return shortTransactionIdOfLength(id, 14);
}

String shortTransactionIdOfLength(String id, int length) {
  int transactionLength = length - 4;
  int endLength = length ~/ 2;
  int startLength = transactionLength - endLength;
  if (id.length > length) {
    return '${id.substring(0, startLength)}... ${id.substring(id.length - endLength)}';
  }
  return id;
}

String shortTransactionHex(String hex) {
  if (hex.length > 603) {
    return '${hex.substring(0, 600)}...';
  }
  return hex;
}