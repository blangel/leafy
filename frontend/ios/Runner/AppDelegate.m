#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#import "Leafy/Leafy.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  FlutterViewController* controller = (FlutterViewController*)self.window.rootViewController;
  FlutterMethodChannel* leafyChannel = [FlutterMethodChannel
                methodChannelWithName:@"leafy/core"
                binaryMessenger:controller.binaryMessenger];
  [leafyChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
      if ([@"createNewWallet" isEqualToString:call.method]) {
        [self handleCreateNewWallet:call andResult:result];
      } else if ([@"getAddresses" isEqualToString:call.method]) {
        [self handleGetAddresses:call andResult:result];
      } else if ([@"createTransaction" isEqualToString:call.method]) {
        [self handleCreateTransaction:call andResult:result];
      } else if ([@"createAndSignTransaction" isEqualToString:call.method]) {
        [self handleCreateAndSignTransaction:call andResult:result];
      } else if ([@"createEphemeralSocialKeyPair" isEqualToString:call.method]) {
        [self handleCreateEphemeralSocialKeyPair:call andResult:result];
      } else if ([@"validateEphemeralSocialPublicKey" isEqualToString:call.method]) {
        [self handleValidateEphemeralSocialPublicKey:call andResult:result];
      } else if ([@"encryptWithEphemeralSocialPublicKey" isEqualToString:call.method]) {
        [self handleEncryptWithEphemeralSocialPublicKey:call andResult:result];
      } else if ([@"decryptWithEphemeralSocialPrivateKey" isEqualToString:call.method]) {
        [self handleDecryptWithEphemeralSocialPrivateKey:call andResult:result];
      } else {
        result(FlutterMethodNotImplemented);
      }
  }];

  [GeneratedPluginRegistrant registerWithRegistry:self];
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void) handleCreateNewWallet:(FlutterMethodCall*) call
                     andResult:(FlutterResult) result {
  @try {
    NSString *networkName = call.arguments[@"networkName"];
    NSError *error;
    NSData *json = LeafyMobileCreateNewWallet(networkName, &error);
    if (error) {
      result([FlutterError errorWithCode:@"CreateNewWallet Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      result(json);
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"CreateNewWallet Failure"
                               message:[e reason]
                               details:nil]);
  }
}

- (void) handleGetAddresses:(FlutterMethodCall*) call
                  andResult:(FlutterResult) result {
  @try {
    NSString *networkName = call.arguments[@"networkName"];
    NSString *firstMnemonic = call.arguments[@"firstMnemonic"];
    NSString *secondDescriptor = call.arguments[@"secondDescriptor"];
    NSString *startIndex = call.arguments[@"startIndex"];
    NSString *num = call.arguments[@"num"];
    NSError *error;
    NSData *json = LeafyMobileGetAddresses(networkName, firstMnemonic, secondDescriptor, [startIndex longLongValue], [num longLongValue], &error);
    if (error) {
      result([FlutterError errorWithCode:@"GetAddresses Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      NSError *error = nil;
      NSArray *addresses = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];
      if (error) {
        result([FlutterError errorWithCode:@"GetAddresses Deserialization Failure"
                                   message:[error localizedDescription]
                                   details:nil]);
      } else {
        result(addresses);
      }
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"GetAddresses Failure"
                               message:[e reason]
                               details:nil]);
  }
}

- (void) handleCreateTransaction:(FlutterMethodCall*) call
                       andResult:(FlutterResult) result {
  @try {
    NSString *networkName = call.arguments[@"networkName"];
    NSString *utxos = call.arguments[@"utxos"];
    NSString *changeAddress = call.arguments[@"changeAddress"];
    NSString *destinationAddress = call.arguments[@"destinationAddress"];
    NSString *amount = call.arguments[@"amount"];
    NSString *feeRate = call.arguments[@"feeRate"];
    NSError *error;
    NSData *json = LeafyMobileCreateTransaction(networkName, utxos, changeAddress, destinationAddress, [amount longLongValue], [feeRate doubleValue], &error);
    if (error) {
      result([FlutterError errorWithCode:@"CreateTransaction Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      result(json);
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"CreateTransaction Failure"
                               message:[e reason]
                               details:nil]);
  }
}

- (void) handleCreateAndSignTransaction:(FlutterMethodCall*) call
                              andResult:(FlutterResult) result {
  @try {
    NSString *networkName = call.arguments[@"networkName"];
    NSString *firstMnemonic = call.arguments[@"firstMnemonic"];
    NSString *secondMnemonic = call.arguments[@"secondMnemonic"];
    NSString *utxos = call.arguments[@"utxos"];
    NSString *changeAddress = call.arguments[@"changeAddress"];
    NSString *destinationAddress = call.arguments[@"destinationAddress"];
    NSString *amount = call.arguments[@"amount"];
    NSString *feeRate = call.arguments[@"feeRate"];
    NSError *error;
    NSData *transactionHex = LeafyMobileCreateAndSignTransaction(networkName, firstMnemonic, secondMnemonic, utxos, changeAddress, destinationAddress, [amount longLongValue], [feeRate doubleValue], &error);
    if (error) {
      result([FlutterError errorWithCode:@"CreateAndSignTransaction Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      result(transactionHex);
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"CreateAndSignTransaction Failure"
                               message:[e reason]
                               details:nil]);
  }
}

- (void) handleCreateEphemeralSocialKeyPair:(FlutterMethodCall*) call
                                  andResult:(FlutterResult) result {
  @try {
    NSError *error;
    NSData *json = LeafyMobileCreateEphemeralSocialKeyPair(&error);
    if (error) {
      result([FlutterError errorWithCode:@"CreateEphemeralSocialKeyPair Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      result(json);
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"CreateEphemeralSocialKeyPair Failure"
                               message:[e reason]
                               details:nil]);
  }
}

- (void) handleValidateEphemeralSocialPublicKey:(FlutterMethodCall*) call
                                      andResult:(FlutterResult) result {
  @try {
    NSString *publicKeyHex = call.arguments[@"publicKeyHex"];
    NSError *error;
    LeafyMobileValidateEphemeralSocialPublicKey(publicKeyHex, &error);
    if (error) {
      result([FlutterError errorWithCode:@"ValidateEphemeralSocialPublicKey Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      result(nil);
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"ValidateEphemeralSocialPublicKey Failure"
                               message:[e reason]
                               details:nil]);
  }
}

- (void) handleEncryptWithEphemeralSocialPublicKey:(FlutterMethodCall*) call
                                         andResult:(FlutterResult) result {
  @try {
    NSString *publicKeyHex = call.arguments[@"publicKeyHex"];
    NSString *data = call.arguments[@"data"];
    NSError *error;
    NSString *encrypted = LeafyMobileEncryptWithEphemeralSocialPublicKey(publicKeyHex, data, &error);
    if (error) {
      result([FlutterError errorWithCode:@"EncryptWithEphemeralSocialPublicKey Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      result(encrypted);
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"EncryptWithEphemeralSocialPublicKey Failure"
                               message:[e reason]
                               details:nil]);
  }
}

- (void) handleDecryptWithEphemeralSocialPrivateKey:(FlutterMethodCall*) call
                                          andResult:(FlutterResult) result {
  @try {
    NSString *privateKeyHex = call.arguments[@"privateKeyHex"];
    NSString *encrypted = call.arguments[@"encrypted"];
    NSError *error;
    NSString *decrypted = LeafyMobileDecryptWithEphemeralSocialPrivateKey(privateKeyHex, encrypted, &error);
    if (error) {
      result([FlutterError errorWithCode:@"DecryptWithEphemeralSocialPrivateKey Failure"
                                 message:[error localizedDescription]
                                 details:nil]);
    } else {
      result(decrypted);
    }
  } @catch (NSException *e) {
    result([FlutterError errorWithCode:@"DecryptWithEphemeralSocialPrivateKey Failure"
                               message:[e reason]
                               details:nil]);
  }
}

@end
