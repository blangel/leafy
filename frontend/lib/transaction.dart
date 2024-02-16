
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/mempool_space_connectivity.dart';
import 'package:leafy/widget/transaction.dart';
import 'package:leafy/widget/vin.dart';
import 'package:leafy/widget/vout.dart';

class TransactionPage extends StatefulWidget {

  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionState();

}

class _TransactionState extends State<TransactionPage> {

  // TODO - use websockets instead (need support from bitcoinClient implementation)
  Timer? timer;

  int currentBlockHeight = 0;

  MempoolSnapshot? mempoolSnapshot;

  @override
  void initState() {
    super.initState();
    _loadBlockHeight();
    _loadMempoolData();
    _setupRefreshTimer();
  }


  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _loadMempoolData() async {
    // TODO - replace client
    BitcoinClient client = MempoolSpaceClient.mainnet();
    client.getMempoolSnapshot().then((snapshot) {
      if (mounted) {
        setState(() {
          mempoolSnapshot = snapshot;
        });
      }
    });
  }

  void _setupRefreshTimer() async {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 60), (Timer t) {
      _loadBlockHeight();
      _loadMempoolData();
    });
  }

  void _loadBlockHeight() async {
    bitcoinClient.getCurrentBlockHeight().then((height) {
      setState(() {
        currentBlockHeight = height;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as TransactionArgument;
    final Transaction transaction = arguments.transaction;
    return buildScaffold(context, "Transaction", Padding(padding: const EdgeInsets.all(10), child: Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 42, child: Text("TxId", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            Expanded(flex: 1, child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(shortTransactionIdOfLength(transaction.id, 40), textAlign: TextAlign.right),
                SizedBox(width: 24, child: IconButton(onPressed: () {
                  Clipboard.setData(ClipboardData(text: transaction.id)).then((_) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${transaction.id}', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
                  });
                }, icon: const Icon(Icons.copy, size: 16))
                )
              ],
            ))
          ],
        ),
        const SizedBox(height: 10),
        Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("When", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Expanded(flex: 1, child: RichText(textAlign: TextAlign.end, text: TextSpan(
                      text: "${showExpectedBecauseUnconfirmed(transaction) ? 'likely confirming within' : transaction.status.getDateTime()} ",
                      children: [
                        if (showExpectedBecauseUnconfirmed(transaction))
                          ...[
                            TextSpan(text: mempoolSnapshot!.getExpectedDuration(transaction.feeRate()), style: const TextStyle(fontWeight: FontWeight.w200))
                          ]
                        else
                          TextSpan(text: transaction.status.getAgoDurationParenthetical(), style: const TextStyle(fontWeight: FontWeight.w200)),
                      ]
                  )))
                ],
              ),
              if (currentBlockHeight != 0) // still loading
                ...[Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 1, child: getConfirmationWidget(getConfirmationColor(transaction), getConfirmationText(transaction))),
                    if (isUnconfirmedSent(transaction))
                      ...[
                        // TODO - if recovery, handle differently
                        TextButton(
                          onPressed: () {
                            List<Transaction> transactions = getTransactionsForBip125Replacement(arguments.transactions, transaction);
                            Navigator.pushNamed(context, '/create-transaction',
                                arguments: CreateTransactionArguments(keyArguments: arguments.keyArguments,
                                    transactions: transactions, changeAddress: arguments.changeAddress, toReplace: transaction));
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upgrade),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Confirm Faster", style: TextStyle(fontSize: 12)),
                                  Text("replace by increasing fees", style: TextStyle(fontSize: 8)),
                                ],
                              )

                            ],
                          ),
                        ),
                      ]
                  ],
                ),
              ]
            ]
        ),
        const SizedBox(height: 10),
        Expanded(flex: 1, child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          children: [
            const Text("Inputs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Container(padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
                    itemCount: transaction.vins.length,
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                          child: VinRowWidget(vin: transaction.vins[index]));
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return Padding(padding: const EdgeInsets.fromLTRB(5, 0, 5, 5), child: Container());
                    }
                )
            ),
            const SizedBox(height: 10),
            const Text("Outputs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Container(padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
                    itemCount: transaction.vouts.length,
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                          child: VoutRowWidget(vout: transaction.vouts[index]));
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return Padding(padding: const EdgeInsets.fromLTRB(5, 0, 5, 5), child: Container());
                    }
                )
            ),
            const SizedBox(height: 10),
            const Text("Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("Size", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(flex: 1, child:
                        RichText(textAlign: TextAlign.end, text: TextSpan(
                            text: "${transaction.size} ",
                            children: [
                              const TextSpan(text: "B", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                              const TextSpan(text: " (", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                              TextSpan(text: "${transaction.getVirtualBytesFormatted()} ", style: const TextStyle(fontSize: 12)),
                              const TextSpan(text: "vB, ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                              TextSpan(text: "${transaction.weight} ", style: const TextStyle(fontSize: 12)),
                              const TextSpan(text: "wU)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                            ]
                        )))
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("Fees", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(flex: 1, child:
                        RichText(textAlign: TextAlign.end, text: TextSpan(
                            text: "${formatBitcoin(fromSatsToBitcoin(transaction.feeSats.toDouble()))} ",
                            children: [
                              const TextSpan(text: "₿", style: TextStyle(fontWeight: FontWeight.w200)),
                              const TextSpan(text: " (", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                              TextSpan(text: "${transaction.formatFeeRate()} ", style: const TextStyle(fontSize: 12)),
                              const TextSpan(text: "sat/vB", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                              const TextSpan(text: ")", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                            ]
                        )))
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("Version", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(flex: 1, child: Text("${transaction.version}", textAlign: TextAlign.end)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("Locktime", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(flex: 1, child: Text("${transaction.locktime}", textAlign: TextAlign.end,)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text("Liveliness Update", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (transaction.needLivelinessCheck(currentBlockHeight + livelinessUpdateThreshold))
                          ...[
                            Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child:
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (transaction.needLivelinessCheck(currentBlockHeight))
                                    ...[Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(15.0),
                                          ),
                                          child: const Text("past due", style: TextStyle(color: Colors.black), textAlign: TextAlign.end,)
                                      ),
                                    ]
                                  else
                                    ...[Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent,
                                          borderRadius: BorderRadius.circular(15.0),
                                        ),
                                        child: const Text("available", style: TextStyle(color: Colors.black), textAlign: TextAlign.end,)
                                      ),
                                    ],
                                  const SizedBox(width: 5),
                                  TextButton(onPressed: () {
                                    Navigator.pushNamed(context, '/liveliness', arguments: TransactionsArguments(keyArguments: arguments.keyArguments, transactions: arguments.transactions, changeAddress: arguments.changeAddress, currentBlockHeight: arguments.currentBlockHeight));
                                  }, style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text("update ", style: TextStyle(decoration: TextDecoration.underline), textAlign: TextAlign.end,),
                                        Icon(Icons.north_east, size: 10,),
                                      ],
                                  ))
                                ],
                              )))
                          ]
                        else if (transaction.hasAnyOwnedUtxo())
                          ...[
                            Expanded(flex: 1, child: Text("in ${transaction.status.getDurationUntil(arguments.currentBlockHeight + livelinessUpdateThreshold)}", textAlign: TextAlign.end,)),
                          ]
                        else
                          ...[
                            const Expanded(flex: 1, child: Text("n/a", textAlign: TextAlign.end)),
                          ]
                      ],
                    )
                  ],
                )
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
                    launchWebUrl(bitcoinClient.getBitcoinProviderTransactionUrl(transaction.id))
                  },
                  child: Text('view transaction on ${bitcoinClient.getBitcoinProviderName()}',
                    style: const TextStyle(decoration: TextDecoration.underline),
                  ),
                )))
              ],
            )
          ],
        ))
      ],
    )));
  }

  List<Transaction> getTransactionsForBip125Replacement(List<Transaction> transactions, Transaction toReplace) {
    // [BIP-125](https://github.com/bitcoin/bips/blob/master/bip-0125.mediawiki#user-content-Implementation_Details)
    // specifies the replacement must "spends one or more of the same inputs" of the original.
    // To comply, ensure at least one of the original transaction VINs is used
    // Also, to assist in complying with BIP-125 replacement rule 2, remove all other
    // transactions used as VINs in the 'toReplace' which allows us to then unconditionally
    // filter the transactions for those only confirmed.
    List<Transaction> existing = toReplace.vins.map((vin) => Transaction.fromVin(vin)).toList();
    List<Transaction> copied = [];
    copied.addAll(transactions);
    copied.remove(toReplace);
    copied.removeWhere((tx) => existing.contains(tx));
    copied.insert(0, existing.first);
    // handle BIP-125 replacement rule 2 [note, non-confirmed can only be in
    // existing transaction which is handled above].
    copied = copied.where((tx) => tx.status.confirmed).toList();
    // note, this is tenuous and works only b/c the coin selection is FIFO [TODO - change native code to explicitly take UTXO which must be included in selection]
    return copied;
  }

  bool isUnconfirmedSent(Transaction transaction) {
    bool inputSent = transaction.vins.where((vin) => vin.fromKnownAddress).isNotEmpty;
    return inputSent && isUnconfirmed(transaction);
  }

  bool isUnconfirmed(Transaction transaction) {
    if (currentBlockHeight == 0) {
      return false; // not loaded
    }
    int numConfirms = transaction.status.getConfirmations(currentBlockHeight);
    return (numConfirms < 1);
  }

  bool showExpectedBecauseUnconfirmed(Transaction transaction) {
    return isUnconfirmed(transaction) && (mempoolSnapshot != null);
  }

  String getConfirmationText(Transaction transaction) {
    int numConfirms = transaction.status.getConfirmations(currentBlockHeight);
    if (numConfirms < 1) {
      return "unconfirmed";
    } else if (numConfirms == 1) {
      return "${transaction.status.getConfirmationsFormatted(currentBlockHeight)} confirmation";
    }
    return "${transaction.status.getConfirmationsFormatted(currentBlockHeight)} confirmations";
  }

  Color getConfirmationColor(Transaction transaction) {
    int confirmations = transaction.status.getConfirmations(currentBlockHeight);
    if (confirmations <= 0) {
      return Colors.red;
    } else if (confirmations < 6) {
      return Colors.yellow;
    }
    return Colors.green;
  }
}

Widget getConfirmationWidget(Color confirmationColor, String confirmationText) {
  return Align(alignment: Alignment.centerRight, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: confirmationColor,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Text(confirmationText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.end,)
  ));
}