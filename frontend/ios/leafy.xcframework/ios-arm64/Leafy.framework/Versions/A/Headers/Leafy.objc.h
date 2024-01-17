// Objective-C API for talking to leafy Go package.
//   gobind -lang=objc leafy
//
// File is generated by gobind. Do not edit.

#ifndef __Leafy_H__
#define __Leafy_H__

@import Foundation;
#include "ref.h"
#include "Universe.objc.h"


@class LeafyBip44Key;
@class LeafyInMemorySigner;
@class LeafyMobileTransaction;
@class LeafyMobileWallet;
@class LeafyPathItem;
@class LeafySignType;
@class LeafySignedMsg;
@class LeafySocialKeyPair;
@class LeafySpentInput;
@class LeafyTapscriptBuilder;
@class LeafyTapscriptSigningData;
@class LeafyTransactionInfo;
@class LeafyUtxo;
@protocol LeafyRecoveryWallet;
@class LeafyRecoveryWallet;
@protocol LeafySigner;
@class LeafySigner;
@protocol LeafyWallet;
@class LeafyWallet;

@protocol LeafyRecoveryWallet <NSObject>
- (NSString* _Nonnull)getFirstMnemonic;
// skipped method RecoveryWallet.GetSecondDescriptor with unsupported parameter or return types

@end

@protocol LeafySigner <NSObject>
// skipped method Signer.TaprootSign with unsupported parameter or return types

// skipped method Signer.TapscriptSign with unsupported parameter or return types

@end

@protocol LeafyWallet <NSObject>
- (NSString* _Nonnull)getFirstMnemonic;
// skipped method Wallet.GetSecondDescriptor with unsupported parameter or return types

- (NSString* _Nonnull)getSecondMnemonic;
@end

@interface LeafyBip44Key : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
// skipped method Bip44Key.CopyWithNewMaster with unsupported parameter or return types

- (LeafyBip44Key* _Nullable)deriveNextSibling:(NSError* _Nullable* _Nullable)error;
// skipped method Bip44Key.GetAccount with unsupported parameter or return types

// skipped method Bip44Key.GetAccountRaw with unsupported parameter or return types

// skipped method Bip44Key.GetChange with unsupported parameter or return types

// skipped method Bip44Key.GetChangeRaw with unsupported parameter or return types

// skipped method Bip44Key.GetCoin with unsupported parameter or return types

// skipped method Bip44Key.GetCoinRaw with unsupported parameter or return types

- (NSString* _Nonnull)getDerivation;
- (NSString* _Nonnull)getFingerprint;
// skipped method Bip44Key.GetIndex with unsupported parameter or return types

// skipped method Bip44Key.GetIndexRaw with unsupported parameter or return types

- (NSString* _Nonnull)getParentDerivation;
// skipped method Bip44Key.GetPrivateKey with unsupported parameter or return types

// skipped method Bip44Key.GetPublicKey with unsupported parameter or return types

// skipped method Bip44Key.GetPurpose with unsupported parameter or return types

// skipped method Bip44Key.GetPurposeRaw with unsupported parameter or return types

- (NSString* _Nonnull)getTaprootDescriptorForParentWithoutChecksum:(NSString* _Nullable)suffixDerivation;
- (NSString* _Nonnull)getTaprootDescriptorWithoutChecksum:(NSString* _Nullable)suffixDerivation;
- (NSString* _Nonnull)getTaprootParentDescriptorWithoutChecksum:(NSString* _Nullable)suffixDerivation;
- (BOOL)isAccountHardened;
- (BOOL)isChangeHardened;
- (BOOL)isCoinHardened;
- (BOOL)isIndexHardened;
- (BOOL)isPurposeHardened;
@end

@interface LeafyInMemorySigner : NSObject <goSeqRefInterface, LeafySigner> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
// skipped constructor InMemorySigner.NewInMemorySigner with unsupported parameter or return types

// skipped method InMemorySigner.TaprootSign with unsupported parameter or return types

// skipped method InMemorySigner.TapscriptSign with unsupported parameter or return types

@end

@interface LeafyMobileTransaction : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
@property (nonatomic) NSString* _Nonnull hex;
@property (nonatomic) int64_t totalInput;
@property (nonatomic) int64_t amount;
@property (nonatomic) int64_t fees;
@property (nonatomic) int64_t change;
@property (nonatomic) BOOL changeIsDust;
@end

@interface LeafyMobileWallet : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
@property (nonatomic) NSString* _Nonnull firstMnemonic;
@property (nonatomic) NSString* _Nonnull secondMnemonic;
@property (nonatomic) NSString* _Nonnull secondDescriptor;
@end

@interface LeafyPathItem : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
- (LeafyPathItem* _Nullable)copy;
@end

@interface LeafySignType : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
- (NSData* _Nullable)getMerkleRoot;
// skipped method SignType.GetSignatureType with unsupported parameter or return types

@end

@interface LeafySignedMsg : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
// skipped field SignedMsg.Msg with unsupported type: *github.com/btcsuite/btcd/wire.MsgTx

@property (nonatomic) NSString* _Nonnull hex;
@end

@interface LeafySocialKeyPair : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
@property (nonatomic) NSString* _Nonnull publicKey;
@property (nonatomic) NSString* _Nonnull privateKey;
@end

@interface LeafySpentInput : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
// skipped field SpentInput.Witness with unsupported type: [][]byte

@end

@interface LeafyTapscriptBuilder : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
// skipped constructor TapscriptBuilder.NewTapscriptBuilder with unsupported parameter or return types

- (LeafyTapscriptBuilder* _Nullable)addLeafScript:(NSData* _Nullable)script;
// skipped method TapscriptBuilder.Address with unsupported parameter or return types

// skipped method TapscriptBuilder.GetInternalKey with unsupported parameter or return types

- (NSData* _Nullable)getMerkleRoot;
// skipped method TapscriptBuilder.GetTapLeaves with unsupported parameter or return types

// skipped method TapscriptBuilder.Script with unsupported parameter or return types

- (LeafyTapscriptSigningData* _Nullable)toSign:(long)leafIndex error:(NSError* _Nullable* _Nullable)error;
@end

@interface LeafyTapscriptSigningData : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
// skipped field TapscriptSigningData.Leaf with unsupported type: github.com/btcsuite/btcd/txscript.TapLeaf

// skipped field TapscriptSigningData.LeafScript with unsupported type: leafy.TapscriptLeafScript

// skipped field TapscriptSigningData.ControlBlock with unsupported type: leafy.TapscriptControlBlock

// skipped field TapscriptSigningData.MerkleRoot with unsupported type: github.com/btcsuite/btcd/chaincfg/chainhash.Hash

@end

@interface LeafyTransactionInfo : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
@property (nonatomic) NSString* _Nonnull hex;
// skipped field TransactionInfo.MsgTx with unsupported type: *github.com/btcsuite/btcd/wire.MsgTx

@property (nonatomic) int64_t txInputAmt;
@property (nonatomic) int64_t txDestAmt;
@property (nonatomic) int64_t txFeeAmt;
@property (nonatomic) int64_t txChangeAmt;
/**
 * IsChangeDust returns dust amount for a P2TR output
 */
- (BOOL)isChangeDust;
@end

@interface LeafyUtxo : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
@property (nonatomic) NSString* _Nonnull fromAddress;
// skipped field Utxo.Outpoint with unsupported type: github.com/btcsuite/btcd/wire.OutPoint

@property (nonatomic) int64_t amount;
@property (nonatomic) NSString* _Nonnull script;
- (NSData* _Nullable)decodeScript:(NSError* _Nullable* _Nullable)error;
@end

// skipped const Bare with unsupported type: leafy.SignatureType

FOUNDATION_EXPORT const int64_t LeafyDefaultTimelock;
// skipped const NoScript with unsupported type: leafy.SignatureType

FOUNDATION_EXPORT const int64_t LeafyP2trDustAmt;
// skipped const Script with unsupported type: leafy.SignatureType


@interface Leafy : NSObject
// skipped variable Timelock with unsupported type: uint32

@end

FOUNDATION_EXPORT NSData* _Nullable LeafyAugmentWithTimelock(int64_t timelock, NSData* _Nullable script, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT LeafySignType* _Nullable LeafyBareSignType(void);

// skipped function CreateAndSignRecoveryTransaction with unsupported parameter or return types


// skipped function CreateAndSignTransaction with unsupported parameter or return types


// skipped function CreateBip44Key with unsupported parameter or return types


FOUNDATION_EXPORT LeafySocialKeyPair* _Nullable LeafyCreateEphemeralSocialKeyPair(NSError* _Nullable* _Nullable error);

/**
 * CreateNewWallet creates two hdkeychain.RecommendedSeedLen length seeds and their associated BIP-39 mnemonics.
 */
FOUNDATION_EXPORT id<LeafyWallet> _Nullable LeafyCreateNewWallet(NSError* _Nullable* _Nullable error);

// skipped function CreateTapscriptTimelockFromKey with unsupported parameter or return types


// skipped function CreateTransaction with unsupported parameter or return types


FOUNDATION_EXPORT NSString* _Nonnull LeafyDecryptWithEphemeralSocialPrivateKey(NSString* _Nullable privateKeyHex, NSString* _Nullable encrypted, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT NSString* _Nonnull LeafyEncryptWithEphemeralSocialPublicKey(NSString* _Nullable publicKeyHex, NSString* _Nullable data, NSError* _Nullable* _Nullable error);

/**
 * GenerateMnemonic creates a hdkeychain.RecommendedSeedLen length seed and then a BIP-39 mnemonic from it
 */
FOUNDATION_EXPORT NSString* _Nonnull LeafyGenerateMnemonic(NSError* _Nullable* _Nullable error);

// skipped function GetAddresses with unsupported parameter or return types


// skipped function GetDescriptor with unsupported parameter or return types


// skipped function GetTaprootAddress with unsupported parameter or return types


FOUNDATION_EXPORT LeafyBip44Key* _Nullable LeafyImportFromTaprootDescriptorForParentWithoutChecksum(NSString* _Nullable descriptor, LeafyPathItem* _Nullable index, NSError* _Nullable* _Nullable error);

/**
 * Inscribe puts 'data' into an [inscription-like](https://docs.ordinals.com/inscriptions.html) script wrapper
 */
FOUNDATION_EXPORT NSData* _Nullable LeafyInscribe(NSData* _Nullable data, NSError* _Nullable* _Nullable error);

/**
 * MobileCreateAndSignRecoveryTransaction wraps calls to CreateAndSignRecoveryTransaction to conform to gomobile type restrictions
The return type is a JSON serialization of the SignedMsg
 */
FOUNDATION_EXPORT NSData* _Nullable LeafyMobileCreateAndSignRecoveryTransaction(NSString* _Nullable networkName, NSString* _Nullable firstMnemonic, NSString* _Nullable secondDescriptor, NSString* _Nullable utxos, NSString* _Nullable changeAddrSerialized, NSString* _Nullable destAddrSerialized, int64_t amount, double feeRate, NSError* _Nullable* _Nullable error);

/**
 * MobileCreateAndSignTransaction wraps calls to CreateAndSignTransaction to conform to gomobile type restrictions
The return type is a JSON serialization of the SignedMsg
 */
FOUNDATION_EXPORT NSData* _Nullable LeafyMobileCreateAndSignTransaction(NSString* _Nullable networkName, NSString* _Nullable firstMnemonic, NSString* _Nullable secondMnemonic, NSString* _Nullable utxos, NSString* _Nullable changeAddrSerialized, NSString* _Nullable destAddrSerialized, int64_t amount, double feeRate, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT NSData* _Nullable LeafyMobileCreateEphemeralSocialKeyPair(NSError* _Nullable* _Nullable error);

/**
 * MobileCreateNewWallet wraps calls to CreateNewWallet and returns the generated seed phrases and the associated second
seed phrase descriptor
 */
FOUNDATION_EXPORT NSData* _Nullable LeafyMobileCreateNewWallet(NSString* _Nullable networkName, NSError* _Nullable* _Nullable error);

/**
 * MobileCreateTransaction wraps calls to CreateTransaction to conform to gomobile type restrictions
The return type is a JSON serialization of the MobileTransaction
 */
FOUNDATION_EXPORT NSData* _Nullable LeafyMobileCreateTransaction(NSString* _Nullable networkName, NSString* _Nullable utxos, NSString* _Nullable changeAddrSerialized, NSString* _Nullable destAddrSerialized, int64_t amount, double feeRate, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT NSString* _Nonnull LeafyMobileDecryptWithEphemeralSocialPrivateKey(NSString* _Nullable privateKeyHex, NSString* _Nullable encrypted, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT NSString* _Nonnull LeafyMobileEncryptWithEphemeralSocialPublicKey(NSString* _Nullable publicKeyHex, NSString* _Nullable data, NSError* _Nullable* _Nullable error);

/**
 * MobileGetAddresses wraps calls to GetAddresses to conform to gomobile type restrictions
The return type is a JSON serialization of the []string
 */
FOUNDATION_EXPORT NSData* _Nullable LeafyMobileGetAddresses(NSString* _Nullable networkName, NSString* _Nullable firstMnemonic, NSString* _Nullable secondDescriptor, int64_t startIndex, int64_t num, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT BOOL LeafyMobileValidateEphemeralSocialPublicKey(NSString* _Nullable publicKeyHex, NSError* _Nullable* _Nullable error);

// skipped function NewInMemorySigner with unsupported parameter or return types


FOUNDATION_EXPORT id<LeafyRecoveryWallet> _Nullable LeafyNewRecoveryWallet(NSString* _Nullable firstMnemonic, NSString* _Nullable secondDescriptor);

// skipped function NewTapscriptBuilder with unsupported parameter or return types


FOUNDATION_EXPORT id<LeafyWallet> _Nullable LeafyNewWallet(NSString* _Nullable firstMnemonic, NSString* _Nullable secondMnemonic);

FOUNDATION_EXPORT LeafySignType* _Nullable LeafyNoScriptSignType(void);

// skipped function Path with unsupported parameter or return types


// skipped function PathHardened with unsupported parameter or return types


FOUNDATION_EXPORT LeafySignType* _Nullable LeafyScriptSignType(NSData* _Nullable merkleRoot);

// skipped function TimelockToApproximateDuration with unsupported parameter or return types


FOUNDATION_EXPORT BOOL LeafyValidateEphemeralSocialPublicKey(NSString* _Nullable publicKeyHex, NSError* _Nullable* _Nullable error);

@class LeafyRecoveryWallet;

@class LeafySigner;

@class LeafyWallet;

@interface LeafyRecoveryWallet : NSObject <goSeqRefInterface, LeafyRecoveryWallet> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (NSString* _Nonnull)getFirstMnemonic;
// skipped method RecoveryWallet.GetSecondDescriptor with unsupported parameter or return types

@end

@interface LeafySigner : NSObject <goSeqRefInterface, LeafySigner> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
// skipped method Signer.TaprootSign with unsupported parameter or return types

// skipped method Signer.TapscriptSign with unsupported parameter or return types

@end

@interface LeafyWallet : NSObject <goSeqRefInterface, LeafyWallet> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (NSString* _Nonnull)getFirstMnemonic;
// skipped method Wallet.GetSecondDescriptor with unsupported parameter or return types

- (NSString* _Nonnull)getSecondMnemonic;
@end

#endif