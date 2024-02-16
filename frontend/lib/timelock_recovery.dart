import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_multi_formatter/utils/bitcoin_validator/bitcoin_validator.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/data_loader.dart';
import 'package:leafy/util/mempool_space_connectivity.dart';
import 'package:leafy/util/transaction.dart';
import 'package:leafy/widget/address.dart';
import 'package:leafy/widget/recovery_utxo.dart';
import 'package:shimmer/shimmer.dart';

class TimelockRecoveryPage extends StatefulWidget {

  const TimelockRecoveryPage({super.key});

  @override
  State<TimelockRecoveryPage> createState() => _TimelockRecoveryState();

}

class _TimelockRecoveryState extends State<TimelockRecoveryPage> {

  // matches any CSV of 50cd00; this is used to find existing recovery transactions
  // and is only applied when the input is from a known-address (thus implying a
  // recovery transaction)
  static const String _existingRecoveryWitnessMatch = "OP_PUSHBYTES_3 50cd00 OP_CSV";

  final AssetImage _recoverImage = const AssetImage('images/timelock_recovery.gif');

  final List<Utxo> _utxos = [];
  late int _countRecoverable;
  late String _firstRecoverableTime;
  late String _lastRecoverableTime;
  late int _currentBlockHeight;
  late double _usdPrice;
  double _feesPaid = 0;
  String _destAddress = "";

  final Set<Transaction> _existingRecovery = {};

  final TextEditingController newAddressController = TextEditingController();
  final List<String> _addresses = [];

  late DataLoader _loader;
  bool _loadingAddresses = true;

  RecommendedFees? _recommendedFees;
  MempoolSnapshot? _mempoolSnapshot;
  RecommendedFeeRateLevel _level = RecommendedFeeRateLevel.fastest;

  bool _signing = false;

  @override
  void initState() {
    super.initState();
    _loader = DataLoader();
    _loadFeeAndMempoolData();
  }

  @override
  void dispose() {
    _loader.dispose();
    newAddressController.dispose();
    super.dispose();
  }

  void _loadFeeAndMempoolData() async {
    // TODO - switch to bitcoinClient from 'globals'
    BitcoinClient client = MempoolSpaceClient.mainnet();
    client.getRecommendedFees().then((fees) {
      setState(() {
        _recommendedFees = fees;
      });
    });
    client.getMempoolSnapshot().then((snapshot) {
      setState(() {
        _mempoolSnapshot = snapshot;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final timelockArguments = ModalRoute.of(context)!.settings.arguments as TimelockRecoveryArguments;
    _loader.init(timelockArguments.walletFirstMnemonic, timelockArguments.walletSecondDescriptor, (addresses, metadata, paging, usdPrice, currentBlockHeight) {
      if (!context.mounted) {
        return;
      }
      List<Transaction> txs = [];
      List<Transaction> recoveryTxs = [];
      if (metadata != null) {
        txs.addAll(metadata.transactions);
        txs.sort((a, b) => b.compareTo(a));
        recoveryTxs.addAll(metadata.transactions);
        recoveryTxs = recoveryTxs.where((tx) => tx.vins.any((vin) => vin.fromKnownAddress
            && vin.innerWitnessScriptAsm != null
            && vin.innerWitnessScriptAsm!.contains(_existingRecoveryWitnessMatch))).toList();
      }
      Set<Utxo> allUtxos = {};
      allUtxos.addAll(_utxos);
      allUtxos.addAll(getUtxos(txs));
      Set<String> uniqueRecoveredAddresses = {};
      uniqueRecoveredAddresses.addAll(_addresses);
      for (var tx in recoveryTxs) {
        for (var vout in tx.vouts) {
          uniqueRecoveredAddresses.add(vout.scriptPubkeyAddress);
        }
      }
      setState(() {
        _usdPrice = usdPrice;
        _currentBlockHeight = currentBlockHeight;
        _utxos.clear();
        _utxos.addAll(allUtxos);
        _existingRecovery.addAll(recoveryTxs);
        _addresses.clear();
        _addresses.addAll(uniqueRecoveredAddresses);
        if (_destAddress.isEmpty && _addresses.isNotEmpty) {
          _destAddress = _addresses.first;
        }
        _countRecoverable = _countRecoverableTxs();
        _firstRecoverableTime = _getFirstRecoverable();
        _lastRecoverableTime = _getLastRecoverable();
        _loadingAddresses = paging;
      });
      if (_feesPaid == 0 && _destAddress.isNotEmpty) {
        _createTransaction(context, _destAddress);
      }
    });
    return buildHomeScaffold(context, "Remote Account Recovery", Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Center(child: Image(height: 150, image: _recoverImage))),
        Padding(padding: const EdgeInsets.all(10), child: RichText(text: TextSpan(
          text: "Your Remote Account is inaccessible or its Leafy wallet data has been deleted (",
          children: [
            TextSpan(text: "retry your Remote Account", style: const TextStyle(decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()..onTap = () {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            ),
            const TextSpan(text: ").\n\nTo regain access to your wallet you will need to perform a recovery."),
            if (_utxos.isNotEmpty)
              if (_countRecoverable == 0)
                ...[
                  TextSpan(text: " No recoverable funds currently. ${_firstRecoverableTime == _lastRecoverableTime ? 'In $_lastRecoverableTime all funds can be recovered.' : 'In $_firstRecoverableTime some funds can be recovered. In $_lastRecoverableTime all funds can be recovered.'}"),
                ]
              else
                ...[
                TextSpan(text: " Currently, $_countRecoverable funds can be recovered. In $_lastRecoverableTime all funds can be recovered."),
                ],
            if (_existingRecovery.isNotEmpty)
              if (_existingRecovery.length == 1)
                ...[
                  const TextSpan(text: " "),
                  TextSpan(text: "You have already recovered 1 fund.", style: const TextStyle(decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      Navigator.of(context).pushNamed('/transactions', arguments: TransactionsArguments(transactions: _existingRecovery.toList(), keyArguments: KeyArguments(firstMnemonic: timelockArguments.walletFirstMnemonic, secondDescriptor: timelockArguments.walletSecondDescriptor, secondMnemonic: null, walletPassword: null), changeAddress: _destAddress, currentBlockHeight: _currentBlockHeight, recovery: true));
                  }),
                ]
              else
                ...[
                  TextSpan(text: "You have already recovered ${_existingRecovery.length} funds.", style: const TextStyle(decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = () {
                        Navigator.of(context).pushNamed('/transactions', arguments: TransactionsArguments(transactions: _existingRecovery.toList(), keyArguments: KeyArguments(firstMnemonic: timelockArguments.walletFirstMnemonic, secondDescriptor: timelockArguments.walletSecondDescriptor, secondMnemonic: null, walletPassword: null), changeAddress: _destAddress, currentBlockHeight: _currentBlockHeight));
                      }),
                ],
          ]
        ))),
        Padding(padding: const EdgeInsets.fromLTRB(10, 10, 0, 0), child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 70, child: Text("To", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: DropdownButton(
              value: _destAddress,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _addresses.map((String address) {
                return DropdownMenuItem(
                  value: address,
                  child: Padding(padding: const EdgeInsets.all(5), child: Text(shortData(address), style: const TextStyle(fontSize: 14),)),
                );
              }).toList(),
              onChanged: <String>(value) {
                setState(() {
                  _destAddress = value;
                });
                _createTransaction(context, value);
              },
            ))),
            IconButton(
              iconSize: 20,
              tooltip: 'Add address',
              icon: const Icon(Icons.add),
              onPressed: () {
                _newAddressDialogBuilder(context, setState);
              },
            )
          ],
        )),
        Padding(padding: const EdgeInsets.all(10), child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 80, child: Text("Fee Rate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: DropdownButton(
              value: _level,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: RecommendedFeeRateLevel.values.map((RecommendedFeeRateLevel level) {
                return DropdownMenuItem(
                    value: level,
                    child: _recommendedFees == null ?
                    Padding(padding: const EdgeInsets.all(5), child: Text(level.getLabel())) :
                    Padding(padding: const EdgeInsets.all(5), child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(level.getLabel()),
                        Expanded(flex: 1, child: RichText(textAlign: TextAlign.end, text: TextSpan(
                            text: "${_recommendedFees!.getRate(level)} ",
                            children: const [
                              TextSpan(text: "sat/vB", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                            ]
                        )))
                      ],
                    )));
              }).toList(),
              selectedItemBuilder: (context) {
                return RecommendedFeeRateLevel.values.map((RecommendedFeeRateLevel level) {
                  return Padding(padding: const EdgeInsets.all(5), child: Text(level.getLabel()));
                }).toList();
              },
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _level = value;
                });
                if (_destAddress.isNotEmpty) {
                  _createTransaction(context, _destAddress);
                }
              },
            )))
          ],
        )),
        if (_feesPaid != 0)
          ...[Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(textAlign: TextAlign.end, text: TextSpan(
                  text: "you will spend  ",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w200),
                  children: [
                    TextSpan(text: "${formatBitcoin(fromSatsToBitcoin(_feesPaid))} ₿", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: " (", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                    TextSpan(text: formatCurrency(fromSatsToBitcoin(_feesPaid * _usdPrice)), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ") on this recovery", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200)),
                  ]
              )),
              if ((_recommendedFees != null) && (_mempoolSnapshot != null))
                RichText(textAlign: TextAlign.end, text: TextSpan(
                    text: "likely confirming within  ",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w200),
                    children: [
                      TextSpan(text: _recommendedFees!.getExpectedDuration(_level, _mempoolSnapshot!), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]
                ))
            ],
          )
        ],
        Expanded(flex: 1, child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(10), child: Text("Recoverable Funds", style: TextStyle(fontSize: 24), textAlign: TextAlign.start)),
          if (_loadingAddresses)
            ...[Shimmer.fromColors(
                baseColor: Colors.black12,
                highlightColor: Colors.white70,
                enabled: true,
                child: Padding(padding: const EdgeInsets.all(10), child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 10.0,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10,),
                    Container(
                      height: 10.0,
                      color: Colors.white,
                    )
                  ],
                ))
            )]
          else
            if (_utxos.isEmpty)
              ...[const Padding(padding: EdgeInsets.all(10), child: Text("No recoverable funds found"))]
            else
                ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _utxos.length,
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: InkWell(onTap: null, child: RecoveryUtxoRowWidget(utxo: _utxos[index], currentBlockHeight: _currentBlockHeight, strict: true,)));
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20);
                    }
                ),
        ])),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Visibility(
              visible: !_signing && _destAddress.isNotEmpty && !_loadingAddresses && _getRecoverable().isNotEmpty,
              child: FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _signing = true;
                  });
                  _createAndSignRecoveryTransaction(context, _destAddress, timelockArguments.walletFirstMnemonic, timelockArguments.walletSecondDescriptor);
                },
                label: const Text('Recover'),
                icon: const Icon(Icons.chevron_right),
            ),
          )),
        )
      ],
    ));
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
                        if (!_addresses.contains(newAddressController.text)) {
                          _addresses.add(newAddressController.text);
                        }
                        _destAddress = newAddressController.text;
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

  int _countRecoverableTxs() {
    return _utxos.fold(0, (previousValue, utxo) => utxo.status.needLivelinessCheck(_currentBlockHeight) ? previousValue + 1 : previousValue);
  }

  String _getFirstRecoverable() {
    if (_utxos.isEmpty) {
      return "";
    }
    List<int> blocks = _utxos.map((utxo) => utxo.status.blocksToLiveliness(_currentBlockHeight)).toList();
    blocks.sort();
    return blocksToDurationFormatted(blocks.first);
  }

  String _getLastRecoverable() {
    if (_utxos.isEmpty) {
      return "";
    }
    List<int> blocks = _utxos.map((utxo) => utxo.status.blocksToLiveliness(_currentBlockHeight)).toList();
    blocks.sort();
    return blocksToDurationFormatted(blocks.last);
  }

  List<Utxo> _getRecoverable() {
    return _utxos.where((utxo) => utxo.status.needLivelinessCheck(_currentBlockHeight)).toList();
  }

  void _createTransaction(BuildContext context, String destAddress) async {
    List<Utxo> recoverable = _getRecoverable();
    const spendAll = 0;
    var feeRate = _recommendedFees!.getRate(_level).toDouble();
    createTransaction(recoverable, destAddress, destAddress, spendAll, feeRate).then((created) {
      _handleTransactionCreated(created);
    });
  }

  void _handleTransactionCreated(TransactionHex created) {
    if (created.insufficientFunds) {
      if (mounted) {
        setState(() {
          _signing = false;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient fees, try again with lower fees or when fees may be lower.'), showCloseIcon: true));
      }
      return;
    }
    setState(() {
      _feesPaid = created.fees.toDouble();
    });
  }

  void _createAndSignRecoveryTransaction(BuildContext context, String destAddr, String firstMnemonic, String secondDescriptor) async {
    List<Utxo> recoverable = _getRecoverable();
    const spendAll = 0;
    var feeRate = _recommendedFees!.getRate(_level).toDouble();
    createTransaction(recoverable, destAddr, destAddr, spendAll, feeRate).then((created) {
      _handleTransactionCreated(created);
      signRecoveryTransaction(firstMnemonic, secondDescriptor, recoverable, destAddr, destAddr, spendAll, feeRate).then((signed) async {
        try {
          String txId = await bitcoinClient.submitTransaction(signed);
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submitted $txId', overflow: TextOverflow.ellipsis), showCloseIcon: true));
          }
        } on Exception catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit recovery transaction: ${e.toString()}', overflow: TextOverflow.ellipsis,), showCloseIcon: true));
            setState(() {
              _signing = false;
            });
          }
        }
      });
    });
  }
}