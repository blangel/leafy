
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:leafy/util/bitcoin_network_connectivity.dart';

class MempoolSpaceClient extends BitcoinClient {

  final BitcoinNetwork network;

  final String internetProtocol;

  final String baseUrl;

  MempoolSpaceClient({required this.network, required this.internetProtocol, required this.baseUrl});

  factory MempoolSpaceClient.regtest() {
    // TODO - configurable api-base?
    return MempoolSpaceClient(network: BitcoinNetwork.regtest, internetProtocol: "http", baseUrl: "localhost:8080");
  }

  factory MempoolSpaceClient.mainnet() {
    return MempoolSpaceClient(network: BitcoinNetwork.mainnet, internetProtocol: "https", baseUrl: "mempool.space");
  }

  @override
  String getBitcoinProviderName() {
    return baseUrl;
  }

  @override
  String getBitcoinProviderTransactionUrl(String transactionId) {
    return "$internetProtocol://$baseUrl/tx/$transactionId";
  }

  @override
  String getBitcoinProviderAddressUrl(String address) {
    return "$internetProtocol://$baseUrl/address/$address";
  }

  @override
  String getBitcoinNetworkName() {
    return network.name;
  }

  @override
  Future<AddressInfo> getAddressInfo(String address) async {
    return await _fetchAddressInfo(address);
  }

  @override
  Future<List<Transaction>> getMempoolTransactions() async {
    return await _fetchMempoolTransactions();
  }

  @override
  Future<List<Transaction>> getAddressTransactions(String address) async {
    return await _fetchAddressTransactions(address);
  }

  @override
  Future<Transaction> augmentTransactionWithUnspentUtxos(Transaction transaction) async {
    // the local mempool.space doesn't support api/address/:address/utxo; https://github.com/mempool/mempool/issues/1184
    // so for consistency across regtest/mainnet, using the api/tx/:txid/outspends
    return await _augmentTransactionWithUnspentUtxos(transaction);
  }

  @override
  Future<int> getCurrentBlockHeight() async {
    return await _fetchCurrentBlockHeight();
  }

  @override
  Future<RecommendedFees> getRecommendedFees() async {
    return await _fetchRecommendedFees();
  }

  @override
  Future<MempoolSnapshot> getMempoolSnapshot() async {
    return await _fetchMempoolSnapshot();
  }

  @override
  Future<String> submitTransaction(String transactionHex) async {
    return await _submitTransaction(transactionHex);
  }

  Future<AddressInfo> _fetchAddressInfo(String address) async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/address/$address'),
    );
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      AddressStats chain = AddressStats.fromMempoolApiJson(json, AddressStatsType.chain);
      AddressStats mempool = AddressStats.fromMempoolApiJson(json, AddressStatsType.mempool);
      return AddressInfo(network, address, chain, mempool);
    } else {
      log("failed to load address info (status code ${response.statusCode}): ${response.body}");
      throw Exception('Failed to load address info: ${response.statusCode}');
    }
  }

  Future<List<Transaction>> _fetchMempoolTransactions() async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/mempool/txids'),
    );
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      if (json is List) {
        return List.from((await _fetchTransactions(json)).where((tx) => tx != null));
      }
    }
    log("failed to load mempool transactions (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to load mempool transactions: ${response.statusCode}');
  }

  Future<List<Transaction?>> _fetchTransactions(List<dynamic> txIds) async {
    List<Transaction?> txs = [];
    for (String txId in txIds) {
      txs.add(await _fetchTransaction(txId).then((Transaction transaction) => transaction, onError: (error) => null));
    }
    return txs;
  }

  Future<Transaction> _fetchTransaction(String txId) async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/tx/$txId'),
    );
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      return Transaction.fromMempoolApiJson(json);
    }
    log("failed to load mempool transaction (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to load mempool transaction: ${response.statusCode}');
  }

  Future<List<Transaction>> _fetchAddressTransactions(String address) async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/address/$address/txs'),
    );
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      if (json is List) {
        return json.map((transactionJson) {
          return Transaction.fromMempoolApiJson(transactionJson);
        }).toList();
      }
    }
    if (response.body.contains("No such mempool or blockchain transaction")) {
      log("failed to load address ($address) transactions [unknown associated transaction] (status code ${response.statusCode}): ${response.body}");
      return [];
    }
    log("failed to load address ($address) transactions (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to load address ($address) transactions: ${response.statusCode}');
  }

  Future<Transaction> _augmentTransactionWithUnspentUtxos(Transaction transaction) async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/tx/${transaction.id}/outspends'),
    );
    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      if (result is List) {
        List<bool> results = result.map((spentJson) {
          return !UnspentUtxo.fromMempoolApiJson(spentJson).spent;
        }).toList();
        return transaction.fromKnownUnspent(results);
      }
    }
    log("failed to augment transaction with unspent utxos (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to augment transaction with unspent utxos: ${response.statusCode}');
  }

  Future<int> _fetchCurrentBlockHeight() async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/blocks/tip/height'),
    );
    if (response.statusCode == 200) {
      return int.parse(response.body);
    }
    log("failed to load current block height (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to load current block height: ${response.statusCode}');
  }

  Future<RecommendedFees> _fetchRecommendedFees() async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/v1/fees/recommended'),
    );
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      return RecommendedFees.fromMempoolApiJson(json);
    }
    log("failed to load recommended fees (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to load recommended fees: ${response.statusCode}');
  }

  Future<MempoolSnapshot> _fetchMempoolSnapshot() async {
    final response = await get(
      Uri.parse('$internetProtocol://$baseUrl/api/mempool'),
    );
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      return MempoolSnapshot.fromMempoolApiJson(json);
    }
    log("failed to load mempool snapshot (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to load mempool snapshot: ${response.statusCode}');
  }

  Future<String> _submitTransaction(String transactionHex) async {
    final response = await post(
      Uri.parse('$internetProtocol://$baseUrl/api/tx'),
      body: transactionHex,
    );
    if (response.statusCode == 200) {
      return response.body;
    }
    log("failed to submit transaction $transactionHex (status code ${response.statusCode}): ${response.body}");
    throw Exception('Failed to submit transaction: ${response.statusCode}');
  }

}