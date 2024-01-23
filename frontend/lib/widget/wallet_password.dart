
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leafy/globals.dart';

class WalletPasswordDialog extends StatefulWidget {

  final bool newPassword;

  final bool unknownUsage;

  const WalletPasswordDialog({super.key, this.newPassword=true, this.unknownUsage=false});

  @override
  State<WalletPasswordDialog> createState() => _WalletPasswordDialogState();

}

class _WalletPasswordDialogState extends State<WalletPasswordDialog> {

  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wallet Password'),
      content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AutofillGroup(child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.newPassword)
                  ...[Padding(padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                    child: RichText(text: TextSpan(
                        text: "Leafy does not recommend using a password. ",
                        style: TextStyle(fontSize: 14, color: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium!
                            .color),
                        children: [
                          TextSpan(
                              text: "Read the documentation", style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              color: Theme
                                  .of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .color),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  launchDocumentation(documentationPasswordUrl);
                                }
                          ),
                          TextSpan(
                              text: " for further context in terms of the risks and rationale for setting a password.",
                              style: TextStyle(fontSize: 14, color: Theme
                                  .of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .color))
                        ]
                    ),
                    ),
                  )],
                TextField(
                    controller: _passwordController,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: widget.newPassword ? 'Enter a wallet password' : 'Enter your wallet password',
                      suffixIcon: IconButton(
                        icon: _showPassword
                            ? const Icon(Icons.visibility_off)
                            : const Icon(Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !_showPassword,
                    enableSuggestions: false,
                    autocorrect: false
                )
              ],
            ));
          }
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            setState(() {
              _passwordController.clear();
              _showPassword = false;
            });
            Navigator.pop(context, null);
          },
          child: Text(widget.unknownUsage ? 'I have no password' : 'Cancel'),
        ),
        TextButton(
          onPressed: () {
            TextInput.finishAutofillContext();
            Navigator.pop(context, _passwordController.text);
          },
          child: const Text('Use'),
        ),
      ],
    );
  }
}