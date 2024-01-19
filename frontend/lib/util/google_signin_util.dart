
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleSignInUtil {

  static GoogleSignInUtil create(void Function(GoogleSignInAccount?) authorizedCallback) {
    var googleSignIn = GoogleSignInUtil._();
    googleSignIn._initState(authorizedCallback);
    return googleSignIn;
  }

  late final GoogleSignIn _googleSignIn;

  GoogleSignInUtil._();

  Future<GoogleSignInAccount?> signIn() async {
    return _googleSignIn.signIn();
  }

  Future<GoogleSignInAccount?> signOut() async {
    return _googleSignIn.signOut();
  }

  Future<bool> isAuthenticated() async {
    return await _googleSignIn.isSignedIn();
  }

  void _initState(void Function(GoogleSignInAccount?) authorizedCallback) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId: '853812438928-2tl812dcap611o1rot1ol44dnpakh7ns.apps.googleusercontent.com',
        scopes: ['https://www.googleapis.com/auth/drive.file','https://www.googleapis.com/auth/drive.appdata'],
      );
    } else if (Platform.isIOS) {
      _googleSignIn = GoogleSignIn(
        clientId: '853812438928-2tl812dcap611o1rot1ol44dnpakh7ns.apps.googleusercontent.com',
        scopes: ['https://www.googleapis.com/auth/drive.file','https://www.googleapis.com/auth/drive.appdata'],
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: ['https://www.googleapis.com/auth/drive.file','https://www.googleapis.com/auth/drive.appdata'],
      );
    }
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      bool isAuthorized = account != null;
      if (kIsWeb && account != null) {
        isAuthorized = await _googleSignIn.canAccessScopes(_googleSignIn.scopes);
      }
      if (isAuthorized) {
        authorizedCallback(account!);
      } else {
        authorizedCallback(null);
      }
    });
  }

}

class GoogleAuthClient extends http.BaseClient {

  static Future<GoogleAuthClient> create(GoogleSignInAccount account) async {
    var client = GoogleAuthClient._(account);
    await client._init();
    return client;
  }

  final GoogleSignInAccount _account;

  late final Map<String, String> _headers;

  final http.Client _client = http.Client();

  GoogleAuthClient._(this._account);

  Future<void> _init() async {
    _headers = await _account.authHeaders;
  }

  @override Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}