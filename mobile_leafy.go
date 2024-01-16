package leafy

import (
	"encoding/json"
	"fmt"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/chaincfg"
	"math"
	"strings"
)

// replication of public api of leafy.go to conform to gomobile type restrictions; see https://pkg.go.dev/golang.org/x/mobile/cmd/gobind#hdr-Type_restrictions

// MobileCreateNewWallet wraps calls to CreateNewWallet and returns the generated seed phrases and the associated second
// seed phrase descriptor
func MobileCreateNewWallet(networkName string) ([]byte, error) {
	wallet, err := CreateNewWallet()
	if err != nil {
		return nil, err
	}
	network, err := parseNetworkName(networkName)
	if err != nil {
		return nil, err
	}
	descriptor, err := wallet.GetSecondDescriptor(network)
	if err != nil {
		return nil, err
	}
	mobileWallet := MobileWallet{
		FirstMnemonic:    wallet.GetFirstMnemonic(),
		SecondMnemonic:   wallet.GetSecondMnemonic(),
		SecondDescriptor: descriptor,
	}
	serialized, err := json.Marshal(mobileWallet)
	if err != nil {
		return nil, wrapError(err)
	}
	return serialized, nil
}

// MobileGetAddresses wraps calls to GetAddresses to conform to gomobile type restrictions
// The return type is a JSON serialization of the []string
func MobileGetAddresses(
	networkName string,
	firstMnemonic string,
	secondDescriptor string,
	startIndex int64,
	num int64,
) ([]byte, error) {
	if startIndex < 0 || startIndex > math.MaxUint32 {
		return nil, wrapError(fmt.Errorf("startIndex must be between [0, %d]", math.MaxUint32))
	}
	if num < 0 || num > math.MaxUint8 {
		return nil, wrapError(fmt.Errorf("num must be between [0, %d]", math.MaxUint8))
	}
	startIndexUint32 := uint32(startIndex)
	numUint8 := uint8(num)
	params, err := parseNetworkName(networkName)
	if err != nil {
		return nil, wrapError(err)
	}
	wallet := NewRecoveryWallet(firstMnemonic, secondDescriptor)
	addresses, err := GetAddresses(params, wallet, startIndexUint32, numUint8)
	if err != nil {
		return nil, wrapError(err)
	}
	serialized, err := json.Marshal(addresses)
	if err != nil {
		return nil, wrapError(err)
	}
	return serialized, nil
}

// MobileCreateTransaction wraps calls to CreateTransaction to conform to gomobile type restrictions
// The return type is a JSON serialization of the MobileTransaction
func MobileCreateTransaction(
	networkName string,
	utxos string,
	changeAddrSerialized string,
	destAddrSerialized string,
	amount int64,
	feeRate float64,
) ([]byte, error) {
	params, err := parseNetworkName(networkName)
	if err != nil {
		return nil, wrapError(err)
	}
	changeAddr, err := btcutil.DecodeAddress(changeAddrSerialized, params)
	if err != nil {
		return nil, wrapError(err)
	}
	destAddr, err := btcutil.DecodeAddress(destAddrSerialized, params)
	if err != nil {
		return nil, wrapError(err)
	}
	var utxosDeserialized []Utxo
	err = json.Unmarshal([]byte(utxos), &utxosDeserialized)
	if err != nil {
		return nil, wrapError(err)
	}
	tx, err := CreateTransaction(utxosDeserialized, changeAddr, destAddr, amount, feeRate)
	if err != nil {
		return nil, wrapError(err)
	}
	mobileTx := MobileTransaction{
		Hex:          fmt.Sprintf("%x", tx.Hex),
		TotalInput:   tx.TxInputAmt,
		Amount:       tx.TxInputAmt - tx.TxFeeAmt - tx.TxChangeAmt,
		Fees:         tx.TxFeeAmt,
		Change:       tx.TxChangeAmt,
		ChangeIsDust: tx.IsChangeDust(),
	}
	serialized, err := json.Marshal(mobileTx)
	if err != nil {
		return nil, wrapError(err)
	}
	return serialized, nil
}

// MobileCreateAndSignTransaction wraps calls to CreateAndSignTransaction to conform to gomobile type restrictions
// The return type is a JSON serialization of the SignedMsg
func MobileCreateAndSignTransaction(
	networkName string,
	firstMnemonic string,
	secondMnemonic string,
	utxos string,
	changeAddrSerialized string,
	destAddrSerialized string,
	amount int64,
	feeRate float64,
) ([]byte, error) {
	params, err := parseNetworkName(networkName)
	if err != nil {
		return nil, wrapError(err)
	}
	changeAddr, err := btcutil.DecodeAddress(changeAddrSerialized, params)
	if err != nil {
		return nil, wrapError(err)
	}
	destAddr, err := btcutil.DecodeAddress(destAddrSerialized, params)
	if err != nil {
		return nil, wrapError(err)
	}
	var utxosDeserialized []Utxo
	err = json.Unmarshal([]byte(utxos), &utxosDeserialized)
	if err != nil {
		return nil, wrapError(err)
	}
	wallet := NewWallet(firstMnemonic, secondMnemonic)
	info, err := CreateAndSignTransaction(params, wallet, utxosDeserialized, changeAddr, destAddr, amount, feeRate)
	if err != nil {
		return nil, wrapError(err)
	}
	serialized, err := json.Marshal(info)
	if err != nil {
		return nil, wrapError(err)
	}
	return serialized, nil
}

// MobileCreateAndSignRecoveryTransaction wraps calls to CreateAndSignRecoveryTransaction to conform to gomobile type restrictions
// The return type is a JSON serialization of the SignedMsg
func MobileCreateAndSignRecoveryTransaction(
	networkName string,
	firstMnemonic string,
	secondDescriptor string,
	utxos string,
	changeAddrSerialized string,
	destAddrSerialized string,
	amount int64,
	feeRate float64,
) ([]byte, error) {
	params, err := parseNetworkName(networkName)
	if err != nil {
		return nil, wrapError(err)
	}
	changeAddr, err := btcutil.DecodeAddress(changeAddrSerialized, params)
	if err != nil {
		return nil, wrapError(err)
	}
	destAddr, err := btcutil.DecodeAddress(destAddrSerialized, params)
	if err != nil {
		return nil, wrapError(err)
	}
	var utxosDeserialized []Utxo
	err = json.Unmarshal([]byte(utxos), &utxosDeserialized)
	if err != nil {
		return nil, wrapError(err)
	}
	wallet := NewRecoveryWallet(firstMnemonic, secondDescriptor)
	info, err := CreateAndSignRecoveryTransaction(params, wallet, utxosDeserialized, changeAddr, destAddr, amount, feeRate)
	if err != nil {
		return nil, wrapError(err)
	}
	serialized, err := json.Marshal(info)
	if err != nil {
		return nil, wrapError(err)
	}
	return serialized, nil
}

func MobileCreateEphemeralSocialKeyPair() ([]byte, error) {
	socialKeyPair, err := CreateEphemeralSocialKeyPair()
	if err != nil {
		return nil, wrapError(err)
	}
	serialized, err := json.Marshal(socialKeyPair)
	if err != nil {
		return nil, wrapError(err)
	}
	return serialized, nil
}

func MobileValidateEphemeralSocialPublicKey(publicKeyHex string) error {
	return ValidateEphemeralSocialPublicKey(publicKeyHex)
}

func MobileEncryptWithEphemeralSocialPublicKey(publicKeyHex string, data string) (string, error) {
	encrypted, err := EncryptWithEphemeralSocialPublicKey(publicKeyHex, data)
	if err != nil {
		return "", err
	}
	return encrypted, nil
}

func MobileDecryptWithEphemeralSocialPrivateKey(privateKeyHex string, encrypted string) (string, error) {
	decrypted, err := DecryptWithEphemeralSocialPrivateKey(privateKeyHex, encrypted)
	if err != nil {
		return "", err
	}
	return decrypted, nil
}

type MobileWallet struct {
	FirstMnemonic    string
	SecondMnemonic   string
	SecondDescriptor string
}

type MobileTransaction struct {
	Hex          string
	TotalInput   int64
	Amount       int64
	Fees         int64
	Change       int64
	ChangeIsDust bool
}

func parseNetworkName(networkName string) (*chaincfg.Params, error) {
	switch strings.ToLower(networkName) {
	case "mainnet":
		return &chaincfg.MainNetParams, nil
	case "regtest":
		return &chaincfg.RegressionNetParams, nil
	case "testnet3":
		fallthrough
	case "testnet":
		return &chaincfg.TestNet3Params, nil
	case "simnet":
		return &chaincfg.SimNetParams, nil
	default:
		return nil, fmt.Errorf("unknown network: %v", networkName)
	}
}

// gomobile binding panics (e.g. "Panic: runtime error: hash of unhashable") if error is a custom implementation of builtin error
func wrapError(err error, prefix ...string) error {
	if err == nil {
		return nil
	}
	errPrefix := "err: "
	if len(prefix) == 1 {
		errPrefix = prefix[0]
	}
	return fmt.Errorf("%v%v", errPrefix, err.Error())
}
