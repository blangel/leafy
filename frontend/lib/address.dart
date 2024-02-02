
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/widget/address.dart';
import 'package:leafy/widget/transaction.dart';

class AddressPage extends StatelessWidget {

  const AddressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as AddressDetailArgument;
    final List<Transaction>? transactions = arguments.transactions;
    return buildScaffold(context, "Address", Padding(padding: const EdgeInsets.all(10), child: Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CopyableDataWidget(data: arguments.addressInfo.address),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Balance", style: TextStyle(fontSize: 24),),
            Expanded(flex: 1, child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: getBalanceWidgets(arguments.addressInfo),
            ))
          ],
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SizedBox(height: 5,)),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.call_received, color: Colors.greenAccent, size: 10)),
            const Text("Received", style: TextStyle(fontSize: 20)),
            Expanded(flex: 1, child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: getReceivedWidgets(arguments.addressInfo),
            ))
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.call_made, color: Colors.redAccent, size: 10)),
            const Text("Sent", style: TextStyle(fontSize: 20)),
            Expanded(flex: 1, child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: getSpentWidgets(arguments.addressInfo),
            ))
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child:
            InkWell(
              onTap: () => {
                launchWebUrl(bitcoinClient.getBitcoinProviderAddressUrl(arguments.addressInfo.address))
              },
              child: Text('view address on ${bitcoinClient.getBitcoinProviderName()}',
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            )))
          ],
        ),
        const SizedBox(height: 10),
        const Text("Transactions", style: TextStyle(fontSize: 24),),
        if (transactions == null || transactions.isEmpty)
          ...[const Padding(padding: EdgeInsets.all(10), child: Text("No transactions"))]
        else
          ...[Expanded(flex: 1, child: Padding(padding: const EdgeInsets.fromLTRB(5, 10, 5, 10), child: ListView.separated(
              shrinkWrap: true,
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                return Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: InkWell(onTap: () {
                      Navigator.pushNamed(context, '/transaction',
                          arguments: TransactionArgument(keyArguments: arguments.keyArguments, transaction: transactions[index], transactions: arguments.allTransactions, changeAddress: arguments.changeAddress));
                    }, child: TransactionRowWidget(transaction: transactions[index].fromSingleKnownAddress(arguments.addressInfo.address))));
              },
              separatorBuilder: (BuildContext context, int index) {
                return Divider(color: Theme
                    .of(context)
                    .textTheme
                    .titleMedium!
                    .color, indent: 20, endIndent: 20);
              }
          )
          ))
          ],
      ],
    )));
  }
}