
import 'package:flutter/material.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/widget/address.dart';

class VoutRowWidget extends StatelessWidget {

  final Vout vout;

  const VoutRowWidget({super.key, required this.vout});

  @override
  Widget build(BuildContext context) {
    Widget voutWidget = Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(shortData(vout.scriptPubkeyAddress)),
        Expanded(flex: 1, child: Text("${formatBitcoin(fromSatsToBitcoin(vout.valueSat.toDouble()))} ₿", textAlign: TextAlign.end)),
        if (vout.toKnownAddress)
          ...[
            const SizedBox(width: 5),
            const Icon(Icons.call_received, color: Colors.greenAccent, size: 10,),
          ]
        else
          ...[],
      ],
    );
    return vout.toKnownAddress ? Container(padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: voutWidget) : Padding(padding: const EdgeInsets.all(5), child: voutWidget);
  }
}