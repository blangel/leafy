
import 'package:intl/intl.dart';
import 'package:leafy/globals.dart';

enum BitcoinNetwork {
  regtest, testnet, simnet, mainnet;
}

enum AddressStatsType {
  chain, mempool;
}

class AddressStats {
  final AddressStatsType type;
  final int numberUtxos;
  final int bitcoinSum;
  final int spentUtxos;
  final int spentBitcoinSum;
  final int transactionCount;

  AddressStats({
    required this.type,
    required this.numberUtxos,
    required this.bitcoinSum,
    required this.spentUtxos,
    required this.spentBitcoinSum,
    required this.transactionCount,
  });

  factory AddressStats.fromMempoolApiJson(Map<String, dynamic> json, AddressStatsType type) {
    String jsonBranch = (type == AddressStatsType.chain ? 'chain_stats' : 'mempool_stats');
    return AddressStats(
      type: type,
      numberUtxos: json[jsonBranch]['funded_txo_count'],
      bitcoinSum: json[jsonBranch]['funded_txo_sum'],
      spentUtxos: json[jsonBranch]['spent_txo_count'],
      spentBitcoinSum: json[jsonBranch]['spent_txo_sum'],
      transactionCount: json[jsonBranch]['tx_count'],
    );
  }

  int getBalance() {
    return bitcoinSum - spentBitcoinSum;
  }
}

class AddressInfo {
  final BitcoinNetwork network;
  final String address;
  final AddressStats chainStats;
  final AddressStats mempoolStats;

  AddressInfo(this.network, this.address, this.chainStats, this.mempoolStats);
}

class TransactionStatus {
  final bool confirmed;
  final int? blockHeight;
  final String? blockHash;
  final int? blockTime;

  TransactionStatus({
    required this.confirmed, required this.blockHeight, required this.blockHash, required this.blockTime
  });

  factory TransactionStatus.fromMempoolApiJson(Map<String, dynamic> json) {
    return TransactionStatus(
      confirmed: json['confirmed'],
      blockHeight: json['block_height'],
      blockHash: json['block_hash'],
      blockTime: json['block_time'],
    );
  }

  String getConfirmationsFormatted(int from) {
    if (blockHeight == null) {
      return "0";
    }
    NumberFormat numberFormat = NumberFormat('#,###', 'en_US');
    return numberFormat.format(getConfirmations(from));
  }

  int getConfirmations(int from) {
    if (blockHeight == null) {
      return 0;
    }
    return (from - blockHeight!) + 1;
  }

  String getDateTime() {
    return getDateTimeFromBlockTime(blockTime);
  }

  String getAgoDuration() {
    int? localBlocktime = blockTime;
    if (localBlocktime == null) {
      return "";
    }
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(localBlocktime * 1000);
    Duration difference = DateTime.now().difference(dateTime);
    int days = difference.inDays;
    int hours = difference.inHours % 24;
    int minutes = difference.inMinutes % 60;
    if (days > 1) {
      return "$days days ago";
    } else if (days > 0) {
      return "$days day ago";
    } else if (hours > 1) {
      return "$hours hours ago";
    } else if (hours > 0) {
      return "$hours hour ago";
    } else if (minutes > 1) {
      return "$minutes minutes ago";
    } else if (minutes > 0) {
      return "$minutes minute ago";
    } else {
      return "just now";
    }
  }

  String getDurationUntil(int currentBlockHeight) {
    int blocks = blocksToLiveliness(currentBlockHeight);
    return blocksToDurationFormatted(blocks);
  }

  String getAgoDurationParenthetical() {
    String duration = getAgoDuration();
    if (duration.isEmpty) {
      return duration;
    }
    return "($duration)";
  }

  String getDateTimeDuration() {
    String formattedDateTime = getDateTime();
    String duration = getAgoDurationParenthetical();
    return "$formattedDateTime $duration";
  }

  int blocksToLiveliness(int currentBlock) {
    int confirmations = getConfirmations(currentBlock);
    return timelock - confirmations;
  }

  bool needLivelinessCheck(int currentBlock) {
    int confirmations = getConfirmations(currentBlock);
    return confirmations >= timelock;
  }

  @override
  String toString() {
    return 'TransactionStatus{confirmed: $confirmed, blockHeight: $blockHeight, blockHash: $blockHash, blockTime: $blockTime}';
  }
}

String getDateTimeFromBlockTime(int? blockTime) {
  if (blockTime == null) {
    return "";
  }
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(blockTime * 1000);
  DateFormat formatter = DateFormat('MMM dd, yyyy hh:mm a');
  return formatter.format(dateTime);
}


class PrevOut {

  final int valueSat;
  final String scriptPubkey;
  final String scriptPubkeyAddress;
  final String scriptPubkeyAsm;
  final String scriptPubkeyType;

  PrevOut({required this.valueSat, required this.scriptPubkey, required this.scriptPubkeyAddress,
    required this.scriptPubkeyAsm, required this.scriptPubkeyType});

  factory PrevOut.fromMempoolApiJson(Map<String, dynamic> json) {
    return PrevOut(
      valueSat: json['value'],
      scriptPubkey: json['scriptpubkey'],
      scriptPubkeyAddress: json['scriptpubkey_address'],
      scriptPubkeyAsm: json['scriptpubkey_asm'],
      scriptPubkeyType: json['scriptpubkey_type'],
    );
  }

  @override
  String toString() {
    return 'PrevOut{valueSat: $valueSat, scriptPubkey: $scriptPubkey, scriptPubkeyAddress: $scriptPubkeyAddress, scriptPubkeyAsm: $scriptPubkeyAsm, scriptPubkeyType: $scriptPubkeyType}';
  }
}

class Vin {

  final bool isCoinbase;
  final PrevOut prevOut;
  final String? scriptSig;
  final String? scriptSigAsm;
  final int sequence;
  final String txId;
  final int vout;
  final List<String>? witness;
  final String? innerRedeemScriptAsm;
  final String? innerWitnessScriptAsm;
  final int index;
  final bool fromKnownAddress;

  Vin({
    required this.isCoinbase,
    required this.prevOut,
    required this.scriptSig,
    required this.scriptSigAsm,
    required this.sequence,
    required this.txId,
    required this.vout,
    required this.witness,
    required this.innerRedeemScriptAsm,
    required this.innerWitnessScriptAsm,
    required this.index,
    this.fromKnownAddress = false});

  factory Vin.fromMempoolApiJson(Map<String, dynamic> json, int index) {
    return Vin(
      isCoinbase: json['is_coinbase'],
      prevOut: PrevOut.fromMempoolApiJson(json['prevout']),
      scriptSig: json['scriptsig'],
      scriptSigAsm: json['scriptsig_asm'],
      sequence: json['sequence'],
      txId: json['txid'],
      vout: json['vout'],
      witness: (json['witness'] as List?)?.map((witnessItem) => witnessItem as String).toList(),
      innerRedeemScriptAsm: json['inner_redeemscript_asm'],
      innerWitnessScriptAsm: json['inner_witnessscript_asm'],
      index: index,
    );
  }

  Vin fromKnownAddresses(List<String> addresses) {
    return Vin(
      isCoinbase: isCoinbase,
      prevOut: prevOut,
      scriptSig: scriptSig,
      scriptSigAsm: scriptSigAsm,
      sequence: sequence,
      txId: txId,
      vout: vout,
      witness: witness,
      innerRedeemScriptAsm: innerRedeemScriptAsm,
      innerWitnessScriptAsm: innerWitnessScriptAsm,
      index: index,
      fromKnownAddress: addresses.contains(prevOut.scriptPubkeyAddress),
    );
  }

  @override
  String toString() {
    return 'Vin{isCoinbase: $isCoinbase, prevOut: $prevOut, scriptSig: $scriptSig, scriptSigAsm: $scriptSigAsm, sequence: $sequence, txId: $txId, vout: $vout, witness: $witness, innerRedeemScriptAsm: $innerRedeemScriptAsm, innerWitnessScriptAsm: $innerWitnessScriptAsm, index: $index}';
  }
}

class Vout {
  final int valueSat;
  final String scriptPubkey;
  final String scriptPubkeyAddress;
  final String scriptPubkeyAsm;
  final String scriptPubkeyType;
  final int index;
  final bool toKnownAddress;
  final bool unspent;

  Vout({required this.valueSat, required this.scriptPubkey, required this.scriptPubkeyAddress,
    required this.scriptPubkeyAsm, required this.scriptPubkeyType, required this.index, this.toKnownAddress = false, this.unspent = false});

  factory Vout.fromMempoolApiJson(Map<String, dynamic> json, int index) {
    return Vout(
      valueSat: json['value'],
      scriptPubkey: json['scriptpubkey'],
      scriptPubkeyAddress: json['scriptpubkey_address'],
      scriptPubkeyAsm: json['scriptpubkey_asm'],
      scriptPubkeyType: json['scriptpubkey_type'],
      index: index,
    );
  }

  Vout fromKnownAddresses(List<String> addresses) {
    return Vout(
      valueSat: valueSat,
      scriptPubkey: scriptPubkey,
      scriptPubkeyAddress: scriptPubkeyAddress,
      scriptPubkeyAsm: scriptPubkeyAsm,
      scriptPubkeyType: scriptPubkeyType,
      index: index,
      toKnownAddress: addresses.contains(scriptPubkeyAddress),
    );
  }

  Vout fromKnownUnspent(bool unspent) {
    return Vout(
      valueSat: valueSat,
      scriptPubkey: scriptPubkey,
      scriptPubkeyAddress: scriptPubkeyAddress,
      scriptPubkeyAsm: scriptPubkeyAsm,
      scriptPubkeyType: scriptPubkeyType,
      index: index,
      toKnownAddress: toKnownAddress,
      unspent: unspent,
    );
  }

  @override
  String toString() {
    return 'Vout{valueSat: $valueSat, scriptPubkey: $scriptPubkey, scriptPubkeyAddress: $scriptPubkeyAddress, scriptPubkeyAsm: $scriptPubkeyAsm, scriptPubkeyType: $scriptPubkeyType, index: $index}';
  }
}

class RBFTransaction {

  final RBFTransactionInfo tx;
  final int time;
  final bool fullRbf;
  final int? interval;
  final List<RBFTransaction> replaces;

  RBFTransaction({required this.tx, required this.time, required this.fullRbf, required this.replaces, required this.interval});

  factory RBFTransaction.fromMempoolApiJson(Map<String, dynamic> json) {
    var replacesJson = json['replaces'];
    List<RBFTransaction> replaces = [];
    if (replacesJson is List) {
      replaces = replacesJson.asMap().map((index, replaceJson) {
        return MapEntry(index, RBFTransaction.fromMempoolApiJson(replaceJson));
      }).values.toList();
    }
    return RBFTransaction(
      tx: RBFTransactionInfo.fromMempoolApiJson(json['tx']),
      time: json['time'],
      fullRbf: json['fullRbf'],
      replaces: replaces,
      interval: json.containsKey('interval') ? json['interval'] : null,
    );
  }
}

class RBFTransactionInfo {
  final String id;
  final int fee;
  final double size;
  final int value;
  final double rate;
  final bool rbf;
  final bool? fullRbf;

  RBFTransactionInfo({required this.id, required this.fee, required this.size, required this.value, required this.rate, required this. rbf, required this.fullRbf});

  factory RBFTransactionInfo.fromMempoolApiJson(Map<String, dynamic> json) {
    double size;
    if (json['vsize'] is int) {
      size = (json['vsize'] as int).toDouble();
    } else {
      size = json['vsize'] as double;
    }
    double rate;
    if (json['rate'] is int) {
      rate = (json['rate'] as int).toDouble();
    } else {
      rate = json['rate'] as double;
    }
    return RBFTransactionInfo(
      id: json['txid'],
      fee: json['fee'],
      size: size,
      value: json['value'],
      rate: rate,
      rbf: json['rbf'],
        fullRbf: json.containsKey('fullRbf') ? json['fullRbf'] : null,
    );
  }
}

class Transaction implements Comparable<Transaction> {
  final String id;
  final int version;
  final int locktime;
  final int size;
  final int weight;
  final int feeSats;
  final TransactionStatus status;
  final List<Vin> vins;
  final List<Vout> vouts;
  final int? incoming;
  final int? outgoing;

  Transaction({required this.id, required this.version, required this.locktime,
    required this.size, required this.weight, required this.feeSats, required this.status,
    required this.vins, required this.vouts, this.incoming, this.outgoing});

  // Note, not all values in the Transaction are accurate, use only for fee-bumping
  factory Transaction.fromVin(Vin vin) {
    return Transaction(id: vin.txId, version: -1, locktime: -1, size: -1, weight: -1,
        feeSats: -1, status: TransactionStatus(confirmed: true, blockHash: "", blockHeight: -1, blockTime: -1),
        vins: [], vouts: [Vout(valueSat: vin.prevOut.valueSat, scriptPubkey: vin.prevOut.scriptPubkey,
            scriptPubkeyAsm: vin.prevOut.scriptPubkeyAsm, scriptPubkeyType: vin.prevOut.scriptPubkeyType,
            scriptPubkeyAddress: vin.prevOut.scriptPubkeyAddress, index: vin.vout, toKnownAddress: true, unspent: true)]);
  }

  factory Transaction.fromMempoolApiJson(Map<String, dynamic> json) {
    var vinsJson = json['vin'];
    var voutsJson = json['vout'];
    List<Vin> vins = [];
    List<Vout> vouts = [];
    if (vinsJson is List) {
      vins = vinsJson.asMap().map((index, vinJson) {
        return MapEntry(index, Vin.fromMempoolApiJson(vinJson, index));
      }).values.toList();
    }
    if (voutsJson is List) {
      vouts = voutsJson.asMap().map((index, voutJson) {
        return MapEntry(index, Vout.fromMempoolApiJson(voutJson, index));
      }).values.toList();
    }
    return Transaction(
      id: json['txid'],
      version: json['version'],
      locktime: json['locktime'],
      size: json['size'],
      weight: json['weight'],
      feeSats: json['fee'],
      status: TransactionStatus.fromMempoolApiJson(json['status']),
      vins: vins,
      vouts: vouts,
    );
  }

  Transaction fromKnownAddresses(List<String> addresses) {
    List<Vout> updatedVouts = vouts.map((vout) => vout.fromKnownAddresses(addresses)).toList();
    List<Vin> updatedVins = vins.map((vin) => vin.fromKnownAddresses(addresses)).toList();
    int incoming = vouts.fold(0, (previous, vout) => addresses.contains(vout.scriptPubkeyAddress) ? vout.valueSat + previous : previous);
    int outgoing = vins.fold(0, (previous, vin) => addresses.contains(vin.prevOut.scriptPubkeyAddress) ? vin.prevOut.valueSat + previous : previous);
    return Transaction(id: id, version: version, locktime: locktime, size: size,
      weight: weight, feeSats: feeSats, status: status, vins: updatedVins, vouts: updatedVouts,
      incoming: incoming, outgoing: outgoing,
    );
  }

  Transaction fromKnownUnspent(List<bool> utxos) {
    List<Vout> updatedVouts = vouts.asMap().entries.map((entry) {
      int index = entry.key;
      return entry.value.fromKnownUnspent(utxos[index]);
    }).toList();
    return Transaction(id: id, version: version, locktime: locktime, size: size,
      weight: weight, feeSats: feeSats, status: status, vins: vins, vouts: updatedVouts,
      incoming: incoming, outgoing: outgoing,
    );
  }

  Transaction fromSingleKnownAddress(String address) {
    int incoming = vouts.fold(0, (previous, vout) => address == vout.scriptPubkeyAddress ? vout.valueSat + previous : previous);
    int outgoing = vins.fold(0, (previous, vin) => address == vin.prevOut.scriptPubkeyAddress ? vin.prevOut.valueSat + previous : previous);
    return Transaction(id: id, version: version, locktime: locktime, size: size,
      weight: weight, feeSats: feeSats, status: status, vins: vins, vouts: vouts,
      incoming: incoming, outgoing: outgoing,
    );
  }

  double getVirtualBytes() {
    return (weight / 4);
  }

  String getVirtualBytesFormatted() {
    NumberFormat numberFormat = NumberFormat('#,###.##', 'en_US');
    return numberFormat.format(getVirtualBytes());
  }

  double feeRate() {
    return feeSats / getVirtualBytes();
  }

  String formatFeeRate() {
    NumberFormat numberFormat = NumberFormat('#,###.#', 'en_US');
    return numberFormat.format(feeRate());
  }

  bool hasAnyOwnedUtxo() {
    return vouts.any((vout) => vout.toKnownAddress && vout.unspent);
  }

  bool needLivelinessCheck(int fromBlock) {
    return hasAnyOwnedUtxo() && status.needLivelinessCheck(fromBlock);
  }

  @override
  int compareTo(Transaction other) {
    if (status.confirmed != other.status.confirmed) {
      return status.confirmed ? 1 : -1;
    }
    if (!status.confirmed) {
      return 0;
    }
    return other.status.blockHeight!.compareTo(status.blockHeight!);
  }

  @override
  String toString() {
    return 'Transaction{id: $id, version: $version, locktime: $locktime, size: $size, weight: $weight, feeSats: $feeSats, status: $status, vins: $vins, vouts: $vouts}';
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id;
  }
}

class UnspentUtxo {
  final bool spent;

  UnspentUtxo({required this.spent});

  factory UnspentUtxo.fromMempoolApiJson(Map<String, dynamic> json) {
    return UnspentUtxo(
      spent: json['spent'],
    );
  }
}

enum RecommendedFeeRateLevel {
  fastest, halfHour, hour, economy, minimum;

  String getLabel() {
    switch (this) {
      case RecommendedFeeRateLevel.fastest:
        return "High Priority";
      case RecommendedFeeRateLevel.halfHour:
        return "Medium Priority";
      case RecommendedFeeRateLevel.hour:
        return "Low Priority";
      case RecommendedFeeRateLevel.economy:
        return "No Priority";
      case RecommendedFeeRateLevel.minimum:
        return "Minimum";
      default:
        throw Exception("unknown RecommendedFeeRateLevel $this");
    }
  }
}

class RecommendedFees {

  final int fastestFeeRate;
  final int halfHourFeeRate;
  final int hourFeeRate;
  final int economyFeeRate;
  final int minimumFeeRate;

  RecommendedFees({required this.fastestFeeRate, required this.halfHourFeeRate,
    required this.hourFeeRate, required this.economyFeeRate, required this.minimumFeeRate});

  factory RecommendedFees.fromMempoolApiJson(Map<String, dynamic> json) {
    return RecommendedFees(
      fastestFeeRate: json['fastestFee'],
      halfHourFeeRate: json['halfHourFee'],
      hourFeeRate: json['hourFee'],
      economyFeeRate: json['economyFee'],
      minimumFeeRate: json['minimumFee'],
    );
  }

  RecommendedFees fromMultiple(double multiple) {
    if (multiple <= 1) {
      return this;
    }
    return RecommendedFees(fastestFeeRate: (fastestFeeRate * multiple).toInt(),
        halfHourFeeRate: (halfHourFeeRate * multiple).toInt(),
        hourFeeRate: (hourFeeRate * multiple).toInt(),
        economyFeeRate: (economyFeeRate * multiple).toInt(),
        minimumFeeRate: (minimumFeeRate * multiple).toInt());
  }

  int getRate(RecommendedFeeRateLevel level) {
    switch (level) {
      case RecommendedFeeRateLevel.fastest:
        return fastestFeeRate;
      case RecommendedFeeRateLevel.halfHour:
        return halfHourFeeRate;
      case RecommendedFeeRateLevel.hour:
        return hourFeeRate;
      case RecommendedFeeRateLevel.economy:
        return economyFeeRate;
      case RecommendedFeeRateLevel.minimum:
        return minimumFeeRate;
      default:
        throw Exception("unknown RecommendedFeeRateLevel $level");
    }
  }

  String getExpectedDuration(RecommendedFeeRateLevel level, MempoolSnapshot mempool) {
    switch (level) {
      case RecommendedFeeRateLevel.fastest:
        return mempool.getExpectedDuration(fastestFeeRate.toDouble());
      case RecommendedFeeRateLevel.halfHour:
        return mempool.getExpectedDuration(halfHourFeeRate.toDouble());
      case RecommendedFeeRateLevel.hour:
        return mempool.getExpectedDuration(hourFeeRate.toDouble());
      case RecommendedFeeRateLevel.economy:
        return mempool.getExpectedDuration(economyFeeRate.toDouble());
      case RecommendedFeeRateLevel.minimum:
      // expected in the last block-zone
        return blocksToDurationFormatted(mempool.getEstimatedNumberPendingBlocks());
      default:
        throw Exception("unknown RecommendedFeeRateLevel $level");
    }
  }

}

class Block {
  final String id;
  final int height;
  final int version;
  final int timestamp;
  final int transactionCount;
  final int size;
  final int weight;
  final String merkleRoot;
  final String previousBlockhash;
  final int medianTime;
  final int nonce;
  final int bits;
  final double difficulty;

  Block({required this.id, required this.height, required this.version, required this.timestamp, required this.transactionCount, required this.size, required this.weight, required this.merkleRoot, required this.previousBlockhash, required this.medianTime, required this.nonce, required this.bits, required this.difficulty});

  factory Block.fromMempoolApiJson(Map<String, dynamic> json) {
    double difficulty;
    if (json['difficulty'] is int) {
      difficulty = (json['difficulty'] as int).toDouble();
    } else {
      difficulty = json['difficulty'] as double;
    }
    return Block(
      id: json['id'],
      height: json['height'],
      version: json['version'],
      timestamp: json['timestamp'],
      transactionCount: json['tx_count'],
      size: json['size'],
      weight: json['weight'],
      merkleRoot: json['merkle_root'],
      previousBlockhash: json['previousblockhash'],
      medianTime: json['mediantime'],
      nonce: json['nonce'],
      bits: json['bits'],
      difficulty: difficulty,
    );
  }
}

class MempoolHistogramValue {

  final double feeRate;
  final int size;

  MempoolHistogramValue({required this.feeRate, required this.size});

  factory MempoolHistogramValue.fromMempoolApiJson(List<dynamic> json) {
    return MempoolHistogramValue(
      feeRate: json[0],
      size: json[1],
    );
  }
}

class MempoolSnapshot {

  final int count;
  final int size;
  final int fees;
  final List<MempoolHistogramValue> histogram;

  MempoolSnapshot({required this.count, required this.size, required this.fees, required this.histogram});

  factory MempoolSnapshot.fromMempoolApiJson(Map<String, dynamic> json) {
    var histogramJson = json['fee_histogram'];
    List<MempoolHistogramValue> histogram = [];
    if (histogramJson is List) {
      histogram = histogramJson.map((histogramValue) {
        return MempoolHistogramValue.fromMempoolApiJson(histogramValue);
      }).toList();
    }
    return MempoolSnapshot(
      count: json['count'],
      size: json['vsize'],
      fees: json['total_fee'],
      histogram: histogram,
    );
  }

  int getEstimatedNumberPendingBlocksToFeeRate(double feeRate) {
    int pendingSize = 0;
    for (MempoolHistogramValue value in histogram) {
      if (value.feeRate >= feeRate) {
        pendingSize += value.size;
      }
    }
    return _getEstimatedNumberPendingBlocksBySize(pendingSize);
  }

  String getExpectedDuration(double feeRate) {
    return blocksToDurationFormatted(getEstimatedNumberPendingBlocksToFeeRate(feeRate));
  }

  int getEstimatedNumberPendingBlocks() {
    return _getEstimatedNumberPendingBlocksBySize(size); // size is in vbyte
  }

  static int _getEstimatedNumberPendingBlocksBySize(int vbytes) {
    return (vbytes / 1000000).ceil(); // 1,000,000 vbytes per block
  }

}

abstract class BitcoinClient {
  String getBitcoinProviderProtocol();
  String getBitcoinProviderBaseUrl();
  String getBitcoinProviderName();
  String getBitcoinProviderTransactionUrl(String transactionId);
  String getBitcoinProviderAddressUrl(String address);
  String getBitcoinNetworkName();
  Future<AddressInfo> getAddressInfo(String address);
  Future<List<Transaction>> getMempoolRBFTransactions();
  Future<List<Transaction>> getAddressTransactions(String address);
  Future<Transaction> augmentTransactionWithUnspentUtxos(Transaction transaction);
  Future<int> getCurrentBlockHeight();
  Future<RecommendedFees> getRecommendedFees();
  Future<MempoolSnapshot> getMempoolSnapshot();
  Future<String> submitTransaction(String transactionHex);
}

double fromSatsToBitcoin(double sats) {
  return (sats / 100000000);
}

int fromBitcoinToSats(double bitcoin) {
  return (bitcoin * 100000000).ceil();
}

String formatBitcoin(double value) {
  String string = value.toStringAsFixed(8);
  String trimmed = string.replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  return trimmed;
}

int blocksToDurationMinutes(int blocks) {
  return (blocks * 10);
}

String blocksToDurationFormatted(int blocks) {
  int totalMinutes = blocksToDurationMinutes(blocks);
  Duration duration = Duration(minutes: totalMinutes);
  int days = duration.inDays;
  int hours = duration.inHours % 24;
  int minutes = duration.inMinutes % 60;
  // round up
  if (minutes > 29) {
    hours += 1;
  }
  if (hours > 11) {
    days += 1;
  }
  if (days > 1) {
    return "~$days days";
  } else if (days > 0) {
    return "~$days day";
  } else if (hours > 1) {
    return "~$hours hours";
  } else if (hours > 0) {
    return "~$hours hour";
  } else if (minutes > 10) {
    return "~$minutes minutes";
  } else {
    return "the next block";
  }
}