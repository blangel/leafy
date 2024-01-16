
import 'package:flutter/material.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/widget/address.dart';

class VinRowWidget extends StatelessWidget {

  final Vin vin;

  const VinRowWidget({super.key, required this.vin});

  @override
  Widget build(BuildContext context) {
    Widget vinWidget = Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(shortData(vin.prevOut.scriptPubkeyAddress)),
        Expanded(flex: 1, child: Text("${formatBitcoin(fromSatsToBitcoin(vin.prevOut.valueSat.toDouble()))} ₿", textAlign: TextAlign.end)),
        if (vin.fromKnownAddress)
          ...[
            const SizedBox(width: 5),
            const Icon(Icons.call_made, color: Colors.redAccent, size: 10,),
          ]
        else
          ...[],
      ],
    );
    return vin.fromKnownAddress ? Container(padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: vinWidget) : Padding(padding: const EdgeInsets.all(5), child: vinWidget);
  }
}