
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/address_loader.dart';

class TimelockRecoveryPage extends StatefulWidget {

  const TimelockRecoveryPage({super.key});

  @override
  State<TimelockRecoveryPage> createState() => _TimelockRecoveryState();

}

class _TimelockRecoveryState extends State<TimelockRecoveryPage> {

  late List<String> addresses;

  late AddressMetadata addressMetadata;

  late AddressLoader _loader;

  @override
  void initState() {
    super.initState();
    _loader = AddressLoader();
  }

  @override
  Widget build(BuildContext context) {
    final timelockArguments = ModalRoute.of(context)!.settings.arguments as TimelockRecoveryArguments;
    _loader.init(timelockArguments.walletFirstMnemonic, timelockArguments.walletSecondDescriptor, (addresses, metadata, paging, usdPrice) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        this.addresses = addresses;
        if (metadata != null) {
          addressMetadata = metadata;
        }
      });
    });
    return Container(); // TODO
  }

}