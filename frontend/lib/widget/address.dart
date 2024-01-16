import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';

class CopyableDataWidget extends StatelessWidget {

  final String data;
  final bool shorten;

  const CopyableDataWidget({super.key, required this.data, this.shorten = false});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(10), child: Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 370, child: shorten ? AutoSizeText(data, maxLines: 1, overflow: TextOverflow.ellipsis,) : Text(data, textAlign: TextAlign.right,)),
        Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: SizedBox(width: 24, child: IconButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: data)).then((_) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $data', overflow: TextOverflow.ellipsis,),showCloseIcon: true));
          });
        }, icon: const Icon(Icons.copy, size: 16))))),
      ],
    ));
  }
}

class AddressRowWidget extends StatelessWidget {

  final AddressInfo address;

  const AddressRowWidget({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(shortData(address.address))),
        Expanded(flex: 1, child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: getBalanceWidgets(address),
        ))
      ],
    );
  }

}

String shortData(String data) {
  if (data.length > 34) {
    return '${data.substring(0, 20)}... ${data.substring(data.length - 10)}';
  }
  return data;
}

List<Widget> getBalanceWidgets(AddressInfo address) {
  int chainBalance = address.chainStats.getBalance();
  int mempoolBalance = address.mempoolStats.getBalance();
  return _getWidgets(chainBalance, mempoolBalance, 22);
}

List<Widget> getReceivedWidgets(AddressInfo address) {
  int chainReceived = address.chainStats.bitcoinSum;
  int mempoolReceived = address.mempoolStats.bitcoinSum;
  return _getWidgets(chainReceived, mempoolReceived, 18);
}

List<Widget> getSpentWidgets(AddressInfo address) {
  int chainSpent = address.chainStats.spentBitcoinSum;
  int mempoolSpent = address.mempoolStats.spentBitcoinSum;
  return _getWidgets(chainSpent, mempoolSpent, 18);
}

List<Widget> _getWidgets(int chain, int mempool, int defaultTextSize) {
  return [
    AutoSizeText("${formatBitcoin(fromSatsToBitcoin(chain.toDouble() + mempool))} ₿", style: TextStyle(fontSize: defaultTextSize.toDouble()), textAlign: TextAlign.end, minFontSize: 12, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis),
    if (mempool > 0)
      if (chain <= 0)
        ...[
          const AutoSizeText(" all pending", textAlign: TextAlign.end, minFontSize: 10, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis)
        ]
      else
        ...[
          AutoSizeText(" of which ${formatBitcoin(fromSatsToBitcoin(mempool.toDouble()))} ₿ is pending", textAlign: TextAlign.end, minFontSize: 10, maxLines: 1, stepGranularity: 1, overflow: TextOverflow.ellipsis)
        ]
  ];
}