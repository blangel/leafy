
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/util/data_loader.dart';
import 'package:leafy/util/mempool_space_connectivity.dart';
import 'package:leafy/util/transaction.dart';
import 'package:leafy/widget/recovery_utxo.dart';
import 'package:shimmer/shimmer.dart';

class TimelockRecoveryPage extends StatefulWidget {

  const TimelockRecoveryPage({super.key});

  @override
  State<TimelockRecoveryPage> createState() => _TimelockRecoveryState();

}

class _TimelockRecoveryState extends State<TimelockRecoveryPage> {

  final AssetImage _recoverImage = const AssetImage('images/timelock_recovery.gif');

  late AddressMetadata? _addressMetadata;
  List<Utxo> _utxos = [];
  late int _countRecoverable;
  late String _firstRecoverableTime;
  late String _lastRecoverableTime;
  late int _currentBlockHeight;

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
      if (metadata != null) {
        txs.addAll(metadata.transactions);
        txs.sort((a, b) => b.compareTo(a));
      }
      setState(() {
        _addressMetadata = metadata;
        _currentBlockHeight = currentBlockHeight;
        _utxos = getUtxos(txs);
        _countRecoverable = _utxos.fold(0, (previousValue, utxo) => utxo.status.needLivelinessCheck(_currentBlockHeight) ? previousValue + 1 : previousValue);
        _firstRecoverableTime = _getFirstRecoverable();
        _lastRecoverableTime = _getLastRecoverable();
        _loadingAddresses = paging;
      });
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
            const TextSpan(text: ").\n\nTo regain access to your wallet you will need to perform a recovery. Some of your funds may be timelocked by the Bitcoin blockchain. They will be recoverable after the designated timelock expires.")
          ]
        ))),
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
                // TODO - create transaction to see if funds sufficient for fees
              },
            )))
          ],
        )),
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
              if (_countRecoverable == 0)
                ...[
                  Padding(padding: const EdgeInsets.all(10), child: Text("No recoverable funds currently. ${_firstRecoverableTime == _lastRecoverableTime ? 'In $_lastRecoverableTime all can be recovered.' : 'In $_firstRecoverableTime some can be recovered. In $_lastRecoverableTime all can be recovered.'}")),
                ]
              else
                ...[
                  Padding(padding: const EdgeInsets.all(10), child: Text("$_countRecoverable can be recovered now. In $_lastRecoverableTime all can be recovered.")),
                ],
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
              visible: !_loadingAddresses && _getRecoverable().isNotEmpty,
              child: FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _signing = true;
                  });
                  // TODO - destAddr; where to send?
                  var destAddr = "";
                  _createAndSignRecoveryTransaction(context, destAddr, timelockArguments.walletFirstMnemonic, timelockArguments.walletSecondDescriptor);
                },
                label: const Text('Recover'),
                icon: const Icon(Icons.chevron_right),
            ),
          )),
        )
      ],
    ));
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

  void _createAndSignRecoveryTransaction(BuildContext context, String destAddr, String firstMnemonic, String secondDescriptor) async {
    List<Utxo> recoverable = _getRecoverable();
    const spendAll = 0;
    var feeRate = _recommendedFees!.getRate(_level).toDouble();
    // TODO - createTransaction is the internal-key transaction, no need to use?
    createTransaction(recoverable, destAddr, destAddr, spendAll, feeRate).then((created) {
      if (created.insufficientFunds) {
        // TODO - show insufficient funds to allow user to adjust fees
        if (mounted) {
          setState(() {
            _signing = false;
          });
        }
        return;
      }
      signRecoveryTransaction(firstMnemonic, secondDescriptor, recoverable, destAddr, destAddr, spendAll, feeRate).then((signed) async {
        try {
          String txId = await bitcoinClient.submitTransaction(signed);
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submitted $txId', overflow: TextOverflow.ellipsis), showCloseIcon: true));
            // TODO - now where?
            //Navigator.of(context).popUntil(ModalRoute.withName('/wallet'));
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