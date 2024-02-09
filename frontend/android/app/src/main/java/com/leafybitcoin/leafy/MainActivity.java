package com.leafybitcoin.leafy;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONException;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import leafy.Leafy;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "leafy/core";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                            if ("createNewWallet".equals(call.method)) {
                                handleCreateNewWallet(call, result);
                            } else if ("getAddresses".equals(call.method)) {
                                handleGetAddresses(call, result);
                            } else if ("createTransaction".equals(call.method)) {
                                handleCreateTransaction(call, result);
                            } else if ("createAndSignTransaction".equals(call.method)) {
                                handleCreateAndSignTransaction(call, result);
                            } else if ("createAndSignRecoveryTransaction".equals(call.method)) {
                                handleCreateAndSignRecoveryTransaction(call, result);
                            } else if ("createEphemeralSocialKeyPair".equals(call.method)) {
                                handleCreateEphemeralSocialKeyPair(call, result);
                            } else if ("validateEphemeralSocialPublicKey".equals(call.method)) {
                                handleValidateEphemeralSocialPublicKey(call, result);
                            } else if ("encryptWithEphemeralSocialPublicKey".equals(call.method)) {
                                handleEncryptWithEphemeralSocialPublicKey(call, result);
                            } else if ("decryptWithEphemeralSocialPrivateKey".equals(call.method)) {
                                handleDecryptWithEphemeralSocialPrivateKey(call, result);
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }

    private void handleCreateNewWallet(MethodCall call, MethodChannel.Result result) {
        try {
            final String networkName = call.argument("networkName");
            byte[] json = Leafy.mobileCreateNewWallet(networkName);
            result.success(json);
        } catch (Exception e) {
            result.error("CreateNewWallet Failure", e.getMessage(), null);
        }
    }

    private void handleGetAddresses(MethodCall call, MethodChannel.Result result) {
        try {
            final String networkName = call.argument("networkName");
            final String firstMnemonic = call.argument("firstMnemonic");
            final String secondDescriptor = call.argument("secondDescriptor");
            final String startIndex = call.argument("startIndex");
            final long startIndexLong = startIndex == null ? 0L : Long.parseLong(startIndex);
            final String num = call.argument("num");
            final long numLong = num == null ? 0L : Long.parseLong(num);
            byte[] json = Leafy.mobileGetAddresses(networkName, firstMnemonic, secondDescriptor, startIndexLong, numLong);
            List<String> addresses = parseAddressesJson(json);
            result.success(addresses);
        } catch (Exception e) {
            result.error("GenerateAddresses Failure", e.getMessage(), null);
        }
    }

    private void handleCreateTransaction(MethodCall call, MethodChannel.Result result) {
        try {
            final String networkName = call.argument("networkName");
            final String utxos = call.argument("utxos");
            final String changeAddress = call.argument("changeAddress");
            final String destinationAddress = call.argument("destinationAddress");
            final String amount = call.argument("amount");
            final long amountLong = amount == null ? 0L : Long.parseLong(amount);
            final String feeRate = call.argument("feeRate");
            final double feeRateDouble = feeRate == null ? 0L : Double.parseDouble(feeRate);
            byte[] json = Leafy.mobileCreateTransaction(networkName, utxos, changeAddress, destinationAddress, amountLong, feeRateDouble);
            result.success(json);
        } catch (Exception e) {
            result.error("CreateTransaction Failure", e.getMessage(), null);
        }
    }

    private void handleCreateAndSignTransaction(MethodCall call, MethodChannel.Result result) {
        try {
            final String networkName = call.argument("networkName");
            final String firstMnemonic = call.argument("firstMnemonic");
            final String secondMnemonic = call.argument("secondMnemonic");
            final String utxos = call.argument("utxos");
            final String changeAddress = call.argument("changeAddress");
            final String destinationAddress = call.argument("destinationAddress");
            final String amount = call.argument("amount");
            final long amountLong = amount == null ? 0L : Long.parseLong(amount);
            final String feeRate = call.argument("feeRate");
            final double feeRateDouble = feeRate == null ? 0L : Double.parseDouble(feeRate);
            byte[] transacationHex = Leafy.mobileCreateAndSignTransaction(networkName, firstMnemonic, secondMnemonic, utxos, changeAddress, destinationAddress, amountLong, feeRateDouble);
            result.success(transacationHex);
        } catch (Exception e) {
            result.error("CreateandSignTransaction Failure", e.getMessage(), null);
        }
    }

    private void handleCreateAndSignRecoveryTransaction(MethodCall call, MethodChannel.Result result) {
        try {
            final String networkName = call.argument("networkName");
            final String firstMnemonic = call.argument("firstMnemonic");
            final String secondDescriptor = call.argument("secondDescriptor");
            final String utxos = call.argument("utxos");
            final String changeAddress = call.argument("changeAddress");
            final String destinationAddress = call.argument("destinationAddress");
            final String amount = call.argument("amount");
            final long amountLong = amount == null ? 0L : Long.parseLong(amount);
            final String feeRate = call.argument("feeRate");
            final double feeRateDouble = feeRate == null ? 0L : Double.parseDouble(feeRate);
            byte[] transacationHex = Leafy.mobileCreateAndSignRecoveryTransaction(networkName, firstMnemonic, secondDescriptor, utxos, changeAddress, destinationAddress, amountLong, feeRateDouble);
            result.success(transacationHex);
        } catch (Exception e) {
            result.error("CreateandSignRecoveryTransaction Failure", e.getMessage(), null);
        }
    }

    private List<String> parseAddressesJson(byte[] json) throws JSONException {
        String jsonString = new String(json, StandardCharsets.UTF_8);
        JSONArray jsonArray = new JSONArray(jsonString);
        List<String> addresses = new ArrayList<>(jsonArray.length());
        for (int i = 0; i < jsonArray.length(); i++) {
            addresses.add(jsonArray.getString(i));
        }
        return addresses;
    }

    private void handleCreateEphemeralSocialKeyPair(MethodCall call, MethodChannel.Result result) {
        try {
            byte[] json = Leafy.mobileCreateEphemeralSocialKeyPair();
            result.success(json);
        } catch (Exception e) {
            result.error("CreateEphemeralSocialKeyPair Failure", e.getMessage(), null);
        }
    }

    private void handleValidateEphemeralSocialPublicKey(MethodCall call, MethodChannel.Result result) {
        try {
            final String publicKeyHex = call.argument("publicKeyHex");
            Leafy.mobileValidateEphemeralSocialPublicKey(publicKeyHex);
            result.success(null);
        } catch (Exception e) {
            result.error("ValidateEphemeralSocialPublicKey Failure", e.getMessage(), null);
        }
    }

    private void handleEncryptWithEphemeralSocialPublicKey(MethodCall call, MethodChannel.Result result) {
        try {
            final String publicKeyHex = call.argument("publicKeyHex");
            final String data = call.argument("data");
            String encrypted = Leafy.mobileEncryptWithEphemeralSocialPublicKey(publicKeyHex, data);
            result.success(encrypted);
        } catch (Exception e) {
            result.error("EncryptWithEphemeralSocialPublicKey Failure", e.getMessage(), null);
        }
    }

    private void handleDecryptWithEphemeralSocialPrivateKey(MethodCall call, MethodChannel.Result result) {
        try {
            final String privateKeyHex = call.argument("privateKeyHex");
            final String encrypted = call.argument("encrypted");
            String decrypted = Leafy.mobileDecryptWithEphemeralSocialPrivateKey(privateKeyHex, encrypted);
            result.success(decrypted);
        } catch (Exception e) {
            result.error("DecryptWithEphemeralSocialPrivateKey Failure", e.getMessage(), null);
        }
    }

}
