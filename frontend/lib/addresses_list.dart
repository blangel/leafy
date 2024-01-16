
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';
import 'package:leafy/widget/address.dart';

class AddressesListPage extends StatelessWidget {

  final AssetImage _addressBook = const AssetImage('images/addresses.gif');

  const AddressesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as AddressArguments;
    List<AddressInfo> addresses = arguments.addresses;
    // addresses are in order of generation, for this page invert the order to
    // showcase newer addresses first
    addresses = addresses.reversed.toList();
    return buildScaffold(context, "Addresses",
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
                Image(height: 74, image: _addressBook, alignment: Alignment.centerLeft),
                const Padding(padding: EdgeInsets.all(10), child: Text("Previously Used Addresses", style: TextStyle(fontSize: 20))),
              ],
            )),
            Expanded(flex: 1, child: Padding(padding: const EdgeInsets.all(10), child: ListView.separated(
                shrinkWrap: true,
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  return InkWell(onTap: () {
                    Navigator.pushNamed(context, '/address',
                        arguments: AddressDetailArgument(keyArguments: arguments.keyArguments, addressInfo: addresses[index], transactions: arguments.transactions[addresses[index].address], allTransactions: arguments.allTransactions, changeAddress: arguments.changeAddress));
                  }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: AddressRowWidget(address: addresses[index])));
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(color: Theme
                      .of(context)
                      .textTheme
                      .titleMedium!
                      .color, indent: 20, endIndent: 20);
                }
            )))
          ],
        ));
  }
}