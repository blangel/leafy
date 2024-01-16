
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';

enum Currency {
  usd
}

abstract class PriceService {
  Future<double> getCurrentPrice(Currency currency);
}

class CoinbasePriceService extends PriceService {
  static String baseUrl = "https://api.coinbase.com/v2/prices/spot?currency=";

  @override
  Future<double> getCurrentPrice(Currency currency) async {
    return await _fetchCurrentPrice(currency);
  }

  Future<double> _fetchCurrentPrice(Currency currency) async {
    final response = await get(
      Uri.parse('$baseUrl${currency.name.toUpperCase()}'),
    );
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      return double.parse(json['data']['amount'].toString());
    } else {
      log("failed to load price (status code ${response.statusCode}): ${response.body}");
      throw Exception('Failed to load price: ${response.statusCode}');
    }
  }

}