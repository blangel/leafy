
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/data_loader.dart';
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

  late List<String> _addresses;

  late AddressMetadata? _addressMetadata;
  late List<Utxo> _utxos;
  late int _currentBlockHeight;

  late DataLoader _loader;
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loader = DataLoader();
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timelockArguments = ModalRoute.of(context)!.settings.arguments as TimelockRecoveryArguments;
    _loader.init(timelockArguments.walletFirstMnemonic, timelockArguments.walletSecondDescriptor, (addresses, metadata, paging, usdPrice, currentBlockHeight) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _addresses = addresses;
        _addressMetadata = metadata;
        _currentBlockHeight = currentBlockHeight;
        if (_addressMetadata != null) {
          _utxos = getUtxos(_addressMetadata!.transactions);
        }
        _loadingAddresses = false;
      });
    });
    return buildHomeScaffold(context, "Remote Account Recovery", Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Center(child: Image(height: 150, image: _recoverImage))),
        Expanded(flex: 1, child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(10), child: Text("Recoverable Transactions", style: TextStyle(fontSize: 24), textAlign: TextAlign.start)),
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
              ...[const Padding(padding: EdgeInsets.all(10), child: Text("No recovery transactions"))]
            else
              ...[
                ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _utxos.length,
                    itemBuilder: (context, index) {
                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: InkWell(onTap: null, child: RecoveryUtxoRowWidget(utxo: _utxos[index], currentBlockHeight: _currentBlockHeight,)));
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return Divider(color: Theme.of(context).textTheme.titleMedium!.color, indent: 20, endIndent: 20);
                    }
                ),
              ],
        ]))
      ],
    ));
  }

}