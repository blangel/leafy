
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multi_formatter/utils/bitcoin_validator/bitcoin_validator.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/mempool_space_connectivity.dart';
import 'package:leafy/util/price_service.dart';
import 'package:leafy/util/transaction.dart';
import 'package:leafy/widget/address.dart';
import 'package:leafy/widget/transaction.dart';

class CreateTransactionPage extends StatefulWidget {

  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionState();

}

class _CreateTransactionState extends State<CreateTransactionPage> {

  final AssetImage _sendImage = const AssetImage('images/send.gif');

  final List<String> addresses = [];

  late double usdPrice;

  final int _customAmountIndex = 0;
  final int _allAmountIndex = 1;
  final List<bool> _selectedAmountTypes = <bool>[true, false];

  String? toAddress;

  RecommendedFees? recommendedFees;
  MempoolSnapshot? mempoolSnapshot;

  RecommendedFeeRateLevel level = RecommendedFeeRateLevel.economy;

  // TODO - use websockets instead (need support from bitcoinClient implementation)
  Timer? timer;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController newAddressController = TextEditingController();

  TransactionHex? hex;
  bool signing = false;
  bool readyToSubmit = false;

  @override
  void initState() {
    super.initState();
    _loadFeeAndMempoolData();
    _setupRefreshTimer();
    _loadPriceData();
  }

  @override
  void dispose() {
    timer?.cancel();
    amountController.dispose();
    newAddressController.dispose();
    super.dispose();
  }

  void _loadFeeAndMempoolData() async {
    // TODO - replace client
    BitcoinClient client = MempoolSpaceClient.mainnet();
    client.getRecommendedFees().then((fees) {
      setState(() {
        recommendedFees = fees;
        readyToSubmit = false;
        if (hex != null) {
          hex = hex!.withHex("");
          if (mounted) {
            final arguments = ModalRoute.of(context)!.settings.arguments as CreateTransactionArguments;
            createTransactionHex(arguments.transactions, arguments.changeAddress, toAddress, level);
          }
        }
      });
    });
    client.getMempoolSnapshot().then((snapshot) {
      setState(() {
        mempoolSnapshot = snapshot;
        readyToSubmit = false;
        if (hex != null) {
          hex = hex!.withHex("");
          if (mounted) {
            final arguments = ModalRoute.of(context)!.settings.arguments as CreateTransactionArguments;
            createTransactionHex(arguments.transactions, arguments.changeAddress, toAddress, level);
          }
        }
      });
    });
  }

  void _setupRefreshTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(minutes: 2), (Timer t) => _loadFeeAndMempoolData());
  }

  void _loadPriceData() async {
    usdPrice = await priceService.getCurrentPrice(Currency.usd);
  }

  bool _isReplacement(CreateTransactionArguments arguments) {
    return (arguments.toReplace != null);
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as CreateTransactionArguments;
    if (_isReplacement(arguments)) {
      addresses.clear();
      Vout destination = arguments.toReplace!.vouts.where((vout) => !vout.toKnownAddress).first; // TODO - this could be a self-send and/or multi-destination
      toAddress = destination.scriptPubkeyAddress;
      addresses.add(destination.scriptPubkeyAddress);
      amountController.text = fromSatsToBitcoin(destination.valueSat.toDouble()).toString();
      if (hex == null) {
        createTransactionHex(arguments.transactions, arguments.changeAddress, toAddress, level);
      }
      // TODO - for fee level, need to only use something greater than current transaction fees
    } else if (addresses.isEmpty) {
      Set<String> sentToPreviously = arguments.transactions
          .expand((tx) => tx.vins.expand((vin) => vin.fromKnownAddress ?
      tx.vouts.where((vout) => !vout.toKnownAddress).map((vout) => vout.scriptPubkeyAddress) : const Iterable<String>.empty()))
          .toSet();
      addresses.addAll(sentToPreviously);
    }
    List<RecommendedFeeRateLevel> levelsToUse = ((arguments.toReplace == null) || (recommendedFees == null) ? RecommendedFeeRateLevel.values : RecommendedFeeRateLevel.values.where((rateLevel) {
      bool comparison = (recommendedFees!.getRate(rateLevel) > arguments.toReplace!.feeRate().round());
      return comparison;
    }).toList());
    if (!levelsToUse.contains(RecommendedFeeRateLevel.economy)) {
      level = levelsToUse.last;
    }

    const double fixedWidthLabel = 80;
    return buildScaffold(context, "Send Bitcoin",
        Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image(height: 100, image: _sendImage, alignment: Alignment.centerLeft),
                Expanded(flex: 1, child: Padding(padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(!_hasValidHex()
                            ? (_isReplacement(arguments)) ? "Replace Transaction" : "Create Transaction"
                            : readyToSubmit ? (_isReplacement(arguments)) ? "Submit Replacement" : "Submit Transaction"
                            : (_isReplacement(arguments)) ? "Approve Replacement" : "Approve Transaction",
                            style: const TextStyle(fontSize: 24)),
                        if (_isReplacement(arguments))
                          ...[
                            Text("replacing ${shortTransactionIdOfLength(arguments.toReplace!.id, 45)}", style: const TextStyle(fontSize: 10))
                          ]
                      ],
                    )
                )),
              ],
            ),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.fromLTRB(10, 10, 0, 10), child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: fixedWidthLabel - 10, child: Text("To", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: DropdownButton(
                  value: toAddress,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: addresses.map((String address) {
                    return DropdownMenuItem(
                      value: address,
                      child: Padding(padding: const EdgeInsets.all(5), child: Text(shortData(address), style: const TextStyle(fontSize: 14),)),
                    );
                  }).toList(),
                  onChanged: (_isReplacement(arguments)) ? null : <String>(value) {
                    setState(() {
                      toAddress = value;
                      readyToSubmit = false;
                    });
                    createTransactionHex(arguments.transactions, arguments.changeAddress, value, level);
                  },
                ))),
                IconButton(
                  iconSize: 20,
                  tooltip: 'Add address',
                  icon: const Icon(Icons.add),
                  onPressed: (_isReplacement(arguments)) ? null : () {
                    _newAddressDialogBuilder(context, setState);
                  },
                )
              ],
            )),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.all(10), child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: fixedWidthLabel, child: Text("Amount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child:
                TextFormField(textAlign: TextAlign.end, controller: amountController,
                    onSaved: (value) {
                      setState(() {});
                    },
                    onChanged: (value) {
                      setState(() {
                        readyToSubmit = false;
                        if (!_isValidAmount()) {
                          hex = null;
                        }
                      });
                      createTransactionHex(arguments.transactions, arguments.changeAddress, toAddress, level);
                    },
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_isReplacement(arguments) && _selectedAmountTypes[_customAmountIndex]),
                )),
                const SizedBox(width: 10),
                Align(
                  alignment: Alignment.center,
                  child: ToggleButtons(
                    direction: Axis.horizontal,
                    onPressed: (_isReplacement(arguments)) ? null : (int index) {
                      setState(() {
                        readyToSubmit = false;
                        for (int i = 0; i < _selectedAmountTypes.length; i++) {
                          _selectedAmountTypes[i] = i == index;
                        }
                      });
                      createTransactionHex(arguments.transactions, arguments.changeAddress, toAddress, level);
                    },
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    constraints: const BoxConstraints(
                      minHeight: 30.0,
                      minWidth: 60.0,
                    ),
                    isSelected: _selectedAmountTypes,
                    children: const [
                      Text('Custom'),
                      Text('All'),
                    ],
                  ),
                )
              ],
            )),
            if ((hex == null) || !_isValidAmount())
              ...[]
            else
              if (_insufficientFunds())
                ...[const Padding(padding: EdgeInsets.fromLTRB(10, 0, 10, 10), child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("insufficient funds", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                  ],
                ))]
              else
                Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RichText(textAlign: TextAlign.end, text: TextSpan(
                        text: "to cover fees, you will spend a total of ",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w200),
                        children: [
                          TextSpan(text: "${formatBitcoin(fromSatsToBitcoin(hex!.fees.toDouble()) + double.parse(amountController.text))} ₿", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]
                    )),
                  ],
                )),
            if ((hex != null) && hex!.changeIsDust)
              Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RichText(textAlign: TextAlign.end, text: TextSpan(
                      text: "warning",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.yellowAccent),
                      children: [
                        TextSpan(text: ": produces unusable change, further funding would be required to use", style: TextStyle(fontWeight: FontWeight.w200, color: Theme.of(context).textTheme.bodyMedium!.color)),
                      ]
                  )),
                ],
              ))
            else
              ...[],
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.all(10), child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: fixedWidthLabel, child: Text("Fee Rate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: DropdownButton(
                  value: level,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: levelsToUse.map((RecommendedFeeRateLevel level) {
                    return DropdownMenuItem(
                        value: level,
                        child: recommendedFees == null ?
                        Padding(padding: const EdgeInsets.all(5), child: Text(level.getLabel())) :
                        Padding(padding: const EdgeInsets.all(5), child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(level.getLabel()),
                            Expanded(flex: 1, child: RichText(textAlign: TextAlign.end, text: TextSpan(
                                text: "${recommendedFees!.getRate(level)} ",
                                children: const [
                                  TextSpan(text: "sat/vB", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                                ]
                            )))
                          ],
                        )));
                  }).toList(),
                  selectedItemBuilder: (context) {
                    return levelsToUse.map((RecommendedFeeRateLevel level) {
                      return Padding(padding: const EdgeInsets.all(5), child: Text(level.getLabel()));
                    }).toList();
                  },
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      readyToSubmit = false;
                      level = value;
                    });
                    createTransactionHex(arguments.transactions, arguments.changeAddress, toAddress, value);
                  },
                )))
              ],
            )),
            Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!_hasValidHex())
                  ...[const Text("enter amount and address to see fee estimation", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200), textAlign: TextAlign.end,)]
                else
                  ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RichText(textAlign: TextAlign.end, text: TextSpan(
                            text: "you will spend  ",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w200),
                            children: [
                              TextSpan(text: "${formatBitcoin(fromSatsToBitcoin(hex!.fees.toDouble()))} ₿", style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: " (", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                              TextSpan(text: formatCurrency(fromSatsToBitcoin(hex!.fees.toDouble() * usdPrice)), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ") on this transaction", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                            ]
                        )),
                        if ((recommendedFees != null) && (mempoolSnapshot != null))
                          RichText(textAlign: TextAlign.end, text: TextSpan(
                              text: "likely confirming within  ",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w200),
                              children: [
                                TextSpan(text: recommendedFees!.getExpectedDuration(level, mempoolSnapshot!), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]
                          ))
                      ],
                    ),
                  ],
              ],
            )),
            if (readyToSubmit)
              ...[const SizedBox(height: 10),
                Padding(padding: const EdgeInsets.fromLTRB(10, 10, 0, 10), child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: fixedWidthLabel, child: Text("Signed Transaction", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 5),
                    Expanded(flex: 1, child: Text(shortTransactionHex(hex!.hex), style: const TextStyle(fontSize: 10))),
                    IconButton(
                      iconSize: 20,
                      tooltip: 'Copy Signed Transaction',
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: hex!.hex)).then((_) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${hex!.hex}', overflow: TextOverflow.ellipsis,),showCloseIcon: true));
                        });
                      },
                    )
                  ],
                ))],
            Padding(padding: const EdgeInsets.all(20), child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextButton.icon(onPressed: !_hasValidHex() || signing ? null : () async {
                    setState(() {
                      signing = true;
                    });
                    if (readyToSubmit) {
                      submitTransaction();
                    } else {
                      signTransactionHex(arguments.keyArguments.firstMnemonic, arguments.keyArguments.secondMnemonic!, arguments.transactions, arguments.changeAddress, toAddress, level);
                    }
                  }, icon: Icon(readyToSubmit ? Icons.send : Icons.done), label: Text(readyToSubmit ? 'Submit' : 'Approve', style: const  TextStyle(fontSize: 24)))
                ]
            )),
          ],
        )
    );
  }

  Future<void> _newAddressDialogBuilder(BuildContext context, StateSetter parentState) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: const Text('Add Address'),
                content: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: TextFormField(textAlign: TextAlign.end,
                        validator: (value) {
                          var valid = isBitcoinWalletValid(value);
                          return !valid ? 'Address must be a valid Bitcoin address' : null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: newAddressController,
                        onSaved: (value) {
                          setState(() {});
                        },
                        onChanged: (value) {
                          setState(() {});
                        },
                      ))
                    ]
                ),
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    onPressed: newAddressController.text.isEmpty || !isBitcoinWalletValid(newAddressController.text) ? null : () {
                      parentState(() {
                        if (!addresses.contains(newAddressController.text)) {
                          addresses.add(newAddressController.text);
                        }
                        toAddress = newAddressController.text;
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  bool _isValidAmount() {
    if (_selectedAmountTypes[_allAmountIndex]) {
      return true;
    }
    if (amountController.text.isEmpty) {
      return false;
    }
    try {
      double amount = double.parse(amountController.text);
      return (amount > 0);
    } on FormatException {
      return false;
    }
  }

  bool _hasValidHex() {
    return (hex != null) && !(hex!.insufficientFunds);
  }

  bool _insufficientFunds() {
    return (hex != null) && hex!.insufficientFunds;
  }

  void createTransactionHex(List<Transaction> transactions, String changeAddr, String? destAddr, RecommendedFeeRateLevel level) async {
    if ((recommendedFees == null) || (destAddr == null) || !_isValidAmount()) {
      return;
    }
    int amount = _selectedAmountTypes[_allAmountIndex] ? 0 : fromBitcoinToSats(double.parse(amountController.text));
    createTransaction(getUtxos(transactions), changeAddr, destAddr, amount, recommendedFees!.getRate(level).toDouble()).then((value) {
      setState(() {
        hex = value;
        if (_selectedAmountTypes[_allAmountIndex]) {
          amountController.text = "${fromSatsToBitcoin(value.amount.toDouble())}";
        }
      });
    });
  }

  void signTransactionHex(String firstMnemonic, String secondMnemonic, List<Transaction> transactions, String changeAddr, String? destAddr, RecommendedFeeRateLevel level) async {
    if ((recommendedFees == null) || (destAddr == null) || !_isValidAmount()) {
      return;
    }
    int amount = _selectedAmountTypes[_allAmountIndex] ? 0 : fromBitcoinToSats(double.parse(amountController.text));
    signTransaction(firstMnemonic, secondMnemonic, getUtxos(transactions), changeAddr, destAddr, amount, recommendedFees!.getRate(level).toDouble()).then((value) {
      setState(() {
        hex = hex!.withHex(value);
        signing = false;
        readyToSubmit = true;
      });
    });
  }

  List<Utxo> getUtxos(List<Transaction> transactions) {
    return transactions.map((tx) =>
        tx.vouts.where((vout) => vout.unspent && vout.toKnownAddress).map((vout) => Utxo(address: vout.scriptPubkeyAddress, outpoint: Outpoint.fromTxId(tx.id, vout.index), amount: vout.valueSat, script: vout.scriptPubkey))
    ).expand((utxo) => utxo).toList();
  }

  void submitTransaction() async {
    if (!readyToSubmit || (hex == null) || hex!.hex.isEmpty) {
      return;
    }
    try {
      String txId = await bitcoinClient.submitTransaction(hex!.hex);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submitted $txId', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
        Navigator.of(context).popUntil(ModalRoute.withName('/wallet'));
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit transaction: ${e.toString()}', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
      }
    }
  }
}