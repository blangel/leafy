
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/widget/transaction.dart';

class TransactionsListPage extends StatelessWidget {

  final AssetImage _transactionsImage = const AssetImage('images/transactions.gif');

  const TransactionsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as TransactionsArguments;
    List<Transaction> transactions = arguments.transactions;
    return buildScaffold(context, arguments.recovery ? "Recovery Transactions" : "Transactions",
        Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.all(10), child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image(height: 75, image: _transactionsImage, alignment: Alignment.centerLeft),
                  Padding(padding: const EdgeInsets.all(10), child: Text(arguments.recovery ? "Recovery Transactions" : "Historical Transactions", style: TextStyle(fontSize: 20))),
                ],
              )),
              Expanded(flex: 1, child: Padding(padding: const EdgeInsets.all(10), child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: InkWell(onTap: () {
                          Navigator.pushNamed(context, '/transaction',
                              arguments: TransactionArgument(keyArguments: arguments.keyArguments, transaction: transactions[index], transactions: arguments.transactions, changeAddress: arguments.changeAddress, currentBlockHeight: arguments.currentBlockHeight, recovery: arguments.recovery));
                        }, child: TransactionRowWidget(transaction: transactions[index], currentBlockHeight: arguments.currentBlockHeight,)));
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return Divider(color: Theme
                        .of(context)
                        .textTheme
                        .titleMedium!
                        .color, indent: 20, endIndent: 20);
                  }
              ))),
            ])
    );
  }
}