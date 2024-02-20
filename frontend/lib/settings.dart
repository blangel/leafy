
import 'package:flutter/material.dart';
import 'package:leafy/globals.dart';
import 'package:settings_ui/settings_ui.dart';

class SettingsPage extends StatefulWidget {

  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  String _bitcoinNetworkProtocol = 'https';
  String _bitcoinNetworkUrl = 'mempool.space';

  final TextEditingController _bitcoinNetworkUrlController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _bitcoinNetworkProtocol = bitcoinClient.getBitcoinProviderProtocol();
    _bitcoinNetworkUrl = bitcoinClient.getBitcoinProviderBaseUrl();
    _bitcoinNetworkUrlController.text = _bitcoinNetworkUrl;
  }

  @override
  void dispose() {
    _bitcoinNetworkUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildScaffold(context, "Settings", Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 1, child: SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(
              title: const Text('Bitcoin Network Connectivity'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.hub_outlined),
                  title: const Text('mempool.space URL'),
                  value: Text(bitcoinClient.getBitcoinProviderBaseUrl()),
                  onPressed: (context) {
                    showDialog<_BitcoinNetworkParams>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Bitcoin Network Connectivity", style: TextStyle(fontSize: 18)),
                          content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButton(
                                  value: _bitcoinNetworkProtocol,
                                  items: const [
                                    DropdownMenuItem(value: 'https', child: Text('https')),
                                    DropdownMenuItem(value: 'http', child: Text('http')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _bitcoinNetworkProtocol = value!;
                                    });
                                  }
                                ),
                                const SizedBox(width: 10),
                                SizedBox(width: 200, height: 50, child: TextField(
                                  controller: _bitcoinNetworkUrlController,
                                  decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Enter the base URL'
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _bitcoinNetworkUrl = value;
                                    });
                                  },
                                  enableSuggestions: false,
                                  autocorrect: false
                                ))
                            ]);
                          }),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, null);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, _BitcoinNetworkParams(protocol: _bitcoinNetworkProtocol, url: _bitcoinNetworkUrl));
                              },
                              child: const Text('Set'),
                            ),
                          ],
                        );
                      },
                    ).then((params) {
                      if (params != null) {
                        persistBitcoinClient(params.protocol, params.url).then((value) {
                          setState(() {});
                        });
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        )),
      ]
    ));
  }

}

class _BitcoinNetworkParams {
  final String protocol;
  final String url;

  _BitcoinNetworkParams({required this.protocol, required this.url});

}