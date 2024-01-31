package leafy

import (
	"bytes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"fmt"
	"github.com/btcsuite/btcd/blockchain"
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/btcutil/hdkeychain"
	"github.com/btcsuite/btcd/chaincfg"
	"github.com/btcsuite/btcd/txscript"
	"github.com/btcsuite/btcd/wire"
	"github.com/tyler-smith/go-bip39"
	"math"
)

const P2trDustAmt = 330

const DefaultTimelock = 52560

// Timelock non-const for testing
var Timelock uint32 = DefaultTimelock

// GetAddresses generates 'num' of addresses for the provided Leafy wallet.
func GetAddresses(
	params *chaincfg.Params,
	wallet RecoveryWallet,
	startIndex uint32,
	num uint8,
) ([]string, error) {
	if num < 1 {
		return nil, fmt.Errorf("invalid amount of addresses [%d], must be greater than 0", num)
	}
	firstKey, err := getBip44Key(wallet.GetFirstMnemonic(), params, startIndex)
	if err != nil {
		return nil, err
	}
	secondDescriptor, err := wallet.GetSecondDescriptor(params)
	if err != nil {
		return nil, err
	}
	secondKey, err := ImportFromTaprootDescriptorForParentWithoutChecksum(secondDescriptor, Path(startIndex))
	if err != nil {
		return nil, err
	}
	addresses := make([]string, num)
	for i := uint8(0); i < num; i++ {
		firstPrivateKey, err := firstKey.GetPrivateKey()
		if err != nil {
			return nil, err
		}
		secondPublicKey, err := secondKey.GetPublicKey()
		if err != nil {
			return nil, err
		}
		address, _, _, _, err := createTweakedAddressFromPublicKey(params, secondPublicKey, firstPrivateKey)
		if err != nil {
			return nil, err
		}
		addresses[i] = address.EncodeAddress()
		firstKey, err = firstKey.DeriveNextSibling()
		if err != nil {
			return nil, err
		}
		secondKey, err = secondKey.DeriveNextSibling()
		if err != nil {
			return nil, err
		}
	}

	return addresses, nil
}

// CreateAndSignTransaction uses CreateTransaction and signs the created transaction.
func CreateAndSignTransaction(
	params *chaincfg.Params,
	wallet Wallet,
	utxos []Utxo,
	changeAddress btcutil.Address,
	destination btcutil.Address,
	amount int64,
	feeRate float64,
) (*SignedMsg, error) {
	tx, err := CreateTransaction(utxos, changeAddress, destination, amount, feeRate)
	if err != nil {
		return nil, err
	}
	msgTx := tx.MsgTx.Copy()
	signingKeys, err := findSigningKeys(params, wallet, tx)
	if err != nil {
		return nil, err
	}
	// build PrevOutFetcher
	destFetcher := txscript.NewMultiPrevOutFetcher(nil)
	for _, txin := range msgTx.TxIn {
		outpointScript, found := tx.outpointToScript[txin.PreviousOutPoint.String()]
		if !found {
			return nil, fmt.Errorf("failed to find outpoint script %s", txin.PreviousOutPoint.String())
		}
		outpointAmount, found := tx.outpointToAmt[txin.PreviousOutPoint.String()]
		if !found {
			return nil, fmt.Errorf("failed to find outpoint amount %s", txin.PreviousOutPoint.String())
		}
		destFetcher.AddPrevOut(wire.OutPoint{
			Hash:  txin.PreviousOutPoint.Hash,
			Index: txin.PreviousOutPoint.Index,
		}, &wire.TxOut{
			Value:    outpointAmount,
			PkScript: outpointScript,
		})
	}
	// sign inputs
	witnesses := make([][][]byte, 0)
	for index, txin := range msgTx.TxIn {
		outpointAddr, found := tx.outpointToAddr[txin.PreviousOutPoint.String()]
		if !found {
			return nil, fmt.Errorf("failed to find outpoint %s", txin.PreviousOutPoint.String())
		}
		key, found := signingKeys[outpointAddr]
		if !found {
			return nil, fmt.Errorf("failed to find signing key for outpoint %s @ %s", txin.PreviousOutPoint.String(), outpointAddr)
		}

		signer := NewInMemorySigner(key.tweakedPrivateKey)
		witness, _, err := signer.TaprootSign(destFetcher, msgTx, txscript.SigHashDefault, index, key.merkleRoot)
		if err != nil {
			return nil, err
		}
		txinWitness := make([][]byte, 1)
		witnesses = append(witnesses, txinWitness)
		txinWitness[0] = (*witness)[0]
	}
	// assign witnesses
	for index, witness := range witnesses {
		msgTx.TxIn[index].Witness = witness
	}
	// serialize
	buf := bytes.NewBuffer(make([]byte, 0, msgTx.SerializeSize()))
	if err = msgTx.Serialize(buf); err != nil {
		return nil, err
	}
	msgHex := hex.EncodeToString(buf.Bytes())
	return &SignedMsg{
		Msg: msgTx,
		Hex: msgHex,
	}, nil
}

type signingKeys struct {
	tweakedPrivateKey *btcec.PrivateKey
	merkleRoot        []byte
}

func findSigningKeys(
	params *chaincfg.Params,
	wallet Wallet,
	transactionInfo *TransactionInfo,
) (map[string]*signingKeys, error) {
	firstKey, err := getBip44Key(wallet.GetFirstMnemonic(), params, 0)
	if err != nil {
		return nil, err
	}
	secondKey, err := getBip44Key(wallet.GetSecondMnemonic(), params, 0)
	if err != nil {
		return nil, err
	}
	mapping := make(map[string]*signingKeys, 0)
	allMapped := false
	// Leafy uses up to 1000 addresses
outer:
	for i := uint(0); i < 10; i++ {
		for j := uint8(i * 100); j < uint8(i*100)+100; j++ {
			firstPrivateKey, err := firstKey.GetPrivateKey()
			if err != nil {
				return nil, err
			}
			secondPrivateKey, err := secondKey.GetPrivateKey()
			if err != nil {
				return nil, err
			}
			address, _, tweakedPrivateKey, merkleRoot, _, err := createTweakedAddress(params, secondPrivateKey, firstPrivateKey)
			if err != nil {
				return nil, err
			}
			mapping[address.EncodeAddress()] = &signingKeys{
				tweakedPrivateKey: tweakedPrivateKey,
				merkleRoot:        merkleRoot,
			}
			secondKey, err = secondKey.DeriveNextSibling()
			if err != nil {
				return nil, err
			}
			firstKey, err = firstKey.DeriveNextSibling()
			if err != nil {
				return nil, err
			}
		}
		for _, value := range transactionInfo.outpointToAddr {
			_, found := mapping[value]
			if !found {
				continue outer
			}
		}
		allMapped = true
		break outer
	}
	if !allMapped {
		return nil, fmt.Errorf("failed to find signing keys for inputted addresses")
	}
	return mapping, nil
}

func CreateAndSignRecoveryTransaction(
	params *chaincfg.Params,
	wallet RecoveryWallet,
	utxos []Utxo,
	changeAddress btcutil.Address,
	destination btcutil.Address,
	amount int64,
	feeRate float64,
) (*SignedMsg, error) {
	tx, err := CreateTransaction(utxos, changeAddress, destination, amount, feeRate)
	if err != nil {
		return nil, err
	}
	msgTx := tx.MsgTx.Copy()
	// TODO - should be handled by CreateTransaction?
	for _, txin := range msgTx.TxIn {
		txin.Sequence = Timelock
	}
	signingKeys, err := findSigningRecoveryKeys(params, wallet, tx)
	if err != nil {
		return nil, err
	}
	// build PrevOutFetcher
	destFetcher := txscript.NewMultiPrevOutFetcher(nil)
	for _, txin := range msgTx.TxIn {
		outpointScript, found := tx.outpointToScript[txin.PreviousOutPoint.String()]
		if !found {
			return nil, fmt.Errorf("failed to find outpoint script %s", txin.PreviousOutPoint.String())
		}
		outpointAmount, found := tx.outpointToAmt[txin.PreviousOutPoint.String()]
		if !found {
			return nil, fmt.Errorf("failed to find outpoint amount %s", txin.PreviousOutPoint.String())
		}
		destFetcher.AddPrevOut(wire.OutPoint{
			Hash:  txin.PreviousOutPoint.Hash,
			Index: txin.PreviousOutPoint.Index,
		}, &wire.TxOut{
			Value:    outpointAmount,
			PkScript: outpointScript,
		})
	}
	// sign inputs
	witnesses := make([][][]byte, 0)
	for index, txin := range msgTx.TxIn {
		outpointAddr, found := tx.outpointToAddr[txin.PreviousOutPoint.String()]
		if !found {
			return nil, fmt.Errorf("failed to find outpoint %s", txin.PreviousOutPoint.String())
		}
		key, found := signingKeys[outpointAddr]
		if !found {
			return nil, fmt.Errorf("failed to find signing key for outpoint %s @ %s", txin.PreviousOutPoint.String(), outpointAddr)
		}

		signer := NewInMemorySigner(key.privateKey)
		witness, _, err := signer.TapscriptSign(destFetcher, msgTx, txscript.SigHashDefault, index, key.tapscriptData)
		if err != nil {
			return nil, err
		}
		txinWitness := make([][]byte, 3)
		witnesses = append(witnesses, txinWitness)
		txinWitness[0] = (*witness)[0]
		txinWitness[1] = (*witness)[1]
		txinWitness[2] = (*witness)[2]
	}
	// assign witnesses
	for index, witness := range witnesses {
		msgTx.TxIn[index].Witness = witness
	}
	// serialize
	buf := bytes.NewBuffer(make([]byte, 0, msgTx.SerializeSize()))
	if err = msgTx.Serialize(buf); err != nil {
		return nil, err
	}
	msgHex := hex.EncodeToString(buf.Bytes())
	return &SignedMsg{
		Msg: msgTx,
		Hex: msgHex,
	}, nil
}

type signingRecoveryKeys struct {
	privateKey    *btcec.PrivateKey
	tapscriptData *TapscriptSigningData
}

func findSigningRecoveryKeys(
	params *chaincfg.Params,
	wallet RecoveryWallet,
	transactionInfo *TransactionInfo,
) (map[string]*signingRecoveryKeys, error) {
	firstKey, err := getBip44Key(wallet.GetFirstMnemonic(), params, 0)
	if err != nil {
		return nil, err
	}
	descriptor, err := wallet.GetSecondDescriptor(params)
	if err != nil {
		return nil, err
	}
	secondKey, err := ImportFromTaprootDescriptorForParentWithoutChecksum(descriptor, Path(0))
	if err != nil {
		return nil, err
	}
	mapping := make(map[string]*signingRecoveryKeys, 0)
	allMapped := false
	// Leafy uses up to 1000 addresses
outer:
	for i := uint(0); i < 10; i++ {
		for j := uint8(i * 100); j < uint8(i*100)+100; j++ {
			firstPrivateKey, err := firstKey.GetPrivateKey()
			if err != nil {
				return nil, err
			}
			secondPublicKey, err := secondKey.GetPublicKey()
			if err != nil {
				return nil, err
			}
			address, _, _, tapscriptData, err := createTweakedAddressFromPublicKey(params, secondPublicKey, firstPrivateKey)
			if err != nil {
				return nil, err
			}
			mapping[address.EncodeAddress()] = &signingRecoveryKeys{
				privateKey:    firstPrivateKey,
				tapscriptData: tapscriptData,
			}
			secondKey, err = secondKey.DeriveNextSibling()
			if err != nil {
				return nil, err
			}
			firstKey, err = firstKey.DeriveNextSibling()
			if err != nil {
				return nil, err
			}
		}
		for _, value := range transactionInfo.outpointToAddr {
			_, found := mapping[value]
			if !found {
				continue outer
			}
		}
		allMapped = true
		break outer
	}
	if !allMapped {
		return nil, fmt.Errorf("failed to find signing keys for inputted addresses")
	}
	return mapping, nil
}

type TransactionInfo struct {
	Hex              string
	MsgTx            *wire.MsgTx
	TxInputAmt       int64
	TxDestAmt        int64
	TxFeeAmt         int64
	TxChangeAmt      int64
	outpointToAddr   map[string]string
	outpointToAmt    map[string]int64
	outpointToScript map[string][]byte
}

type SignedMsg struct {
	Msg *wire.MsgTx
	Hex string
}

// IsChangeDust returns dust amount for a P2TR output
func (t *TransactionInfo) IsChangeDust() bool {
	return t.TxChangeAmt <= P2trDustAmt && t.TxChangeAmt != 0
}

// GenerateMnemonic creates a hdkeychain.RecommendedSeedLen length seed and then a BIP-39 mnemonic from it
func GenerateMnemonic() (string, error) {
	seed, err := hdkeychain.GenerateSeed(hdkeychain.RecommendedSeedLen)
	if err != nil {
		return "", err
	}
	return bip39.NewMnemonic(seed)
}

// GetDescriptor returns a descriptor for the BIP-32 derivation used by Leafy for mnemonic
func GetDescriptor(
	params *chaincfg.Params,
	mnemonic string,
) (string, error) {
	bip44Key, err := getBip44Key(mnemonic, params, 0)
	if err != nil {
		return "", err
	}
	return bip44Key.GetTaprootParentDescriptorWithoutChecksum(""), nil
}

type SocialKeyPair struct {
	PublicKey  string
	PrivateKey string
}

func CreateEphemeralSocialKeyPair() (*SocialKeyPair, error) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return nil, err
	}

	publicKey := &privateKey.PublicKey

	privateKeyBytes := x509.MarshalPKCS1PrivateKey(privateKey)
	publicKeyBytes, err := x509.MarshalPKIXPublicKey(publicKey)
	if err != nil {
		return nil, err
	}

	return &SocialKeyPair{
		PublicKey:  fmt.Sprintf("%x", publicKeyBytes),
		PrivateKey: fmt.Sprintf("%x", privateKeyBytes),
	}, nil
}

func ValidateEphemeralSocialPublicKey(publicKeyHex string) error {
	_, err := parseEphemeralSocialPublicKey(publicKeyHex)
	return err
}

func EncryptWithEphemeralSocialPublicKey(publicKeyHex string, data string) (string, error) {
	publicKey, err := parseEphemeralSocialPublicKey(publicKeyHex)
	if err != nil {
		return "", err
	}
	encrypted, err := rsa.EncryptPKCS1v15(rand.Reader, publicKey, []byte(data))
	if err != nil {
		return "", fmt.Errorf("data len %v: %w", len([]byte(data)), err)
	}
	return hex.EncodeToString(encrypted), nil
}

func DecryptWithEphemeralSocialPrivateKey(privateKeyHex string, encrypted string) (string, error) {
	privateKey, err := parseEphemeralSocialPrivateKey(privateKeyHex)
	if err != nil {
		return "", err
	}
	decoded, err := hex.DecodeString(encrypted)
	if err != nil {
		return "", err
	}
	decrypted, err := rsa.DecryptPKCS1v15(rand.Reader, privateKey, decoded)
	if err != nil {
		return "", err
	}
	return string(decrypted), nil
}

func parseEphemeralSocialPublicKey(publicKeyHex string) (*rsa.PublicKey, error) {
	data, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return nil, err
	}
	publicKey, err := x509.ParsePKIXPublicKey(data)
	if err != nil {
		return nil, err
	}
	switch pub := publicKey.(type) {
	case *rsa.PublicKey:
		return pub, nil
	default:
		return nil, fmt.Errorf("invalid ephemeral social public key")
	}
}

func parseEphemeralSocialPrivateKey(privateKeyHex string) (*rsa.PrivateKey, error) {
	data, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		return nil, err
	}
	privateKey, err := x509.ParsePKCS1PrivateKey(data)
	if err != nil {
		return nil, err
	}
	return privateKey, err
}

// CreateTransaction constructs a transaction using the provided 'utxos' sending to 'destAddr'. If change is
// required, the change will be sent to the provided 'changeAddr'. Fees will be determined based
// on the provided 'feeRate' (in sat/vByte).  The' amount' if non-zero is the amount, in sats, to send to 'destAddr'.
// If 'amount' is zero, then all available coins (minus fees) will be sent to destAddr.
//
// If 'amount' is non-zero and there are insufficient funds (either based on 'amount' and/or in combination
// with required fees), then an error of "insufficient funds" is returned).
//
// The first return value is the transaction hex encoded.  The second return value is the transaction
// as a wire.MsgTx.  The third return value is the amount sent in Inputs, in sats.  The fourth return value is the
// amount of fees in sats.  The fifth return value is the change, in sats.  If 'amount' is non-zero, the third return
// value minus the fourth return value and the fifth return value will be the 'amount'.  If 'amount' is zero,
// the third return value minus the fourth return value will be the value sent to 'destAddr' and the fifth return value,
// the change, will be zero.
// TODO - should this be overloaded to take in the Timelock on the inputs?
func CreateTransaction(
	utxos []Utxo,
	changeAddr btcutil.Address,
	destAddr btcutil.Address,
	amount int64,
	feeRate float64,
) (*TransactionInfo, error) {
	if feeRate <= 0 {
		return nil, fmt.Errorf("invalid fee rate; should be >= 0")
	}
	outputScript, err := txscript.PayToAddrScript(destAddr)
	if err != nil {
		return nil, err
	}
	changeScript, err := txscript.PayToAddrScript(changeAddr)
	if err != nil {
		return nil, err
	}
	outpointToAddr := make(map[string]string, 0)
	outpointToAmt := make(map[string]int64, 0)
	outpointToScript := make(map[string][]byte, 0)
	msgTx := &wire.MsgTx{
		Version:  2,
		LockTime: 0,
		TxIn:     []*wire.TxIn{},
		TxOut: []*wire.TxOut{
			{
				Value:    amount,
				PkScript: outputScript,
			},
		},
	}
	spendAll := amount == 0
	matchedUtxos := make([]Utxo, 0)
	unmatchedUtxos := make([]Utxo, 0)
	var matchedAmount int64 = 0
	var unmatchedAmount int64 = 0
	for _, utxo := range utxos {
		if !spendAll && matchedAmount >= amount {
			unmatchedAmount += utxo.Amount
			unmatchedUtxos = append(unmatchedUtxos, utxo)
		} else {
			matchedAmount += utxo.Amount
			matchedUtxos = append(matchedUtxos, utxo)
		}
	}
	if matchedAmount < amount {
		return nil, fmt.Errorf("insufficient funds; need %d have %d", amount, matchedAmount)
	}
	for _, matchedUtxo := range matchedUtxos {
		blankWitness := make([][]byte, 1)
		blankSig := make([]byte, 64)
		blankWitness[0] = blankSig
		msgTx.TxIn = append(msgTx.TxIn, &wire.TxIn{
			PreviousOutPoint: matchedUtxo.Outpoint,
			Sequence:         0,
			Witness:          blankWitness,
		})
		outpointToAddr[matchedUtxo.Outpoint.String()] = matchedUtxo.FromAddress
		outpointToAmt[matchedUtxo.Outpoint.String()] = matchedUtxo.Amount
		decodedScript, err := matchedUtxo.DecodeScript()
		if err != nil {
			return nil, err
		}
		outpointToScript[matchedUtxo.Outpoint.String()] = decodedScript
	}
	// TODO - the weight is pre fee-inputs and change-output; should a placeholder be used?
	weight := blockchain.GetTransactionWeight(btcutil.NewTx(msgTx))
	vSize := (weight + (blockchain.WitnessScaleFactor - 1)) / blockchain.WitnessScaleFactor
	feeNeeded := int64(math.Ceil(feeRate * float64(vSize)))
	feePaid := feeNeeded
	change := matchedAmount - amount
	if spendAll {
		change = 0
		msgTx.TxOut[0].Value = matchedAmount - feeNeeded
	} else {
		if feeNeeded > change {
			feeNeeded -= change
			if feeNeeded > unmatchedAmount {
				return nil, fmt.Errorf("insufficient funds to account for fees; need %d have %d remaining", feeNeeded, unmatchedAmount)
			}
			var matchedFeeAmount int64 = 0
			for _, utxo := range unmatchedUtxos {
				blankWitness := make([][]byte, 1)
				blankSig := make([]byte, 64)
				blankWitness[0] = blankSig
				matchedFeeAmount += utxo.Amount
				matchedAmount += utxo.Amount
				unmatchedAmount -= utxo.Amount
				msgTx.TxIn = append(msgTx.TxIn, &wire.TxIn{
					PreviousOutPoint: utxo.Outpoint,
					Sequence:         0,
					Witness:          blankWitness,
				})
				outpointToAddr[utxo.Outpoint.String()] = utxo.FromAddress
				outpointToAmt[utxo.Outpoint.String()] = utxo.Amount
				decodedScript, err := utxo.DecodeScript()
				if err != nil {
					return nil, err
				}
				outpointToScript[utxo.Outpoint.String()] = decodedScript
				if matchedFeeAmount >= feeNeeded {
					break
				}
			}
			change = matchedFeeAmount - feeNeeded
		} else {
			change -= feeNeeded
		}
	}
	if change > 0 {
		// if change is under the dust amount but there are more inputs, try to add more
		// to alleviate the dusting
		index := 0
		for change <= P2trDustAmt && unmatchedAmount > 0 {
			change += unmatchedUtxos[index].Amount
			unmatchedAmount -= unmatchedUtxos[index].Amount
			matchedAmount += unmatchedUtxos[index].Amount
			msgTx.TxIn = append(msgTx.TxIn, &wire.TxIn{
				PreviousOutPoint: unmatchedUtxos[index].Outpoint,
				Sequence:         0,
			})
			outpointToAddr[unmatchedUtxos[index].Outpoint.String()] = unmatchedUtxos[index].FromAddress
			outpointToAmt[unmatchedUtxos[index].Outpoint.String()] = unmatchedUtxos[index].Amount
			decodedScript, err := unmatchedUtxos[index].DecodeScript()
			if err != nil {
				return nil, err
			}
			outpointToScript[unmatchedUtxos[index].Outpoint.String()] = decodedScript
			index += 1
		}
		msgTx.TxOut = append(msgTx.TxOut, &wire.TxOut{
			Value:    change,
			PkScript: changeScript,
		})
	}
	buf := bytes.NewBuffer(make([]byte, 0, msgTx.SerializeSize()))
	if err = msgTx.Serialize(buf); err != nil {
		return nil, err
	}
	msgHex := hex.EncodeToString(buf.Bytes())
	return &TransactionInfo{
		Hex:              msgHex,
		MsgTx:            msgTx,
		TxInputAmt:       matchedAmount,
		TxFeeAmt:         feePaid,
		TxChangeAmt:      change,
		outpointToAddr:   outpointToAddr,
		outpointToAmt:    outpointToAmt,
		outpointToScript: outpointToScript,
	}, nil
}

func getBip44Key(mnemonic string, params *chaincfg.Params, startIndex uint32) (*Bip44Key, error) {
	seed, err := bip39.EntropyFromMnemonic(mnemonic)
	if err != nil {
		return nil, err
	}
	master, err := hdkeychain.NewMaster(seed, params)
	if err != nil {
		return nil, err
	}
	// conventionally, Leafy will use 44'/0'/0'/0/x with incrementing x for addresses
	// the use of bip-44 is not necessary but provides a standard structure of addresses
	// within Leafy.
	bip44Key, err := CreateBip44Key(master,
		PathHardened(44),
		PathHardened(0),
		PathHardened(0),
		Path(0),
		Path(startIndex))
	if err != nil {
		return nil, err
	}
	return bip44Key, nil
}

func computeHashRaw(data []byte) []byte {
	hash := sha256.Sum256(data)
	return hash[:]
}

func createTweakedAddress(
	params *chaincfg.Params,
	secondKey *btcec.PrivateKey,
	firstKey *btcec.PrivateKey,
) (btcutil.Address, *btcec.PublicKey, *btcec.PrivateKey, []byte, *TapscriptSigningData, error) {
	hash := computeHashRaw(firstKey.Serialize())
	tweakedPrivateKey := txscript.TweakTaprootPrivKey(*secondKey, hash)
	tweakedPublicKey := tweakedPrivateKey.PubKey()

	addr, internalKey, merkleRoot, tapscriptData, err := createTweakedAddressFromTweakedPublicKey(params, tweakedPublicKey, firstKey)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	return addr, internalKey, tweakedPrivateKey, merkleRoot, tapscriptData, nil
}

func createTweakedAddressFromPublicKey(
	params *chaincfg.Params,
	secondPublicKey *btcec.PublicKey,
	firstKey *btcec.PrivateKey,
) (btcutil.Address, *btcec.PublicKey, []byte, *TapscriptSigningData, error) {
	hash := computeHashRaw(firstKey.Serialize())
	tweakedPublicKey := txscript.ComputeTaprootOutputKey(secondPublicKey, hash)
	return createTweakedAddressFromTweakedPublicKey(params, tweakedPublicKey, firstKey)
}

func createTweakedAddressFromTweakedPublicKey(
	params *chaincfg.Params,
	tweakedPublicKey *btcec.PublicKey,
	firstKey *btcec.PrivateKey,
) (btcutil.Address, *btcec.PublicKey, []byte, *TapscriptSigningData, error) {
	builder, err := scriptTweakBuilder(params, tweakedPublicKey, firstKey.PubKey())
	if err != nil {
		return nil, nil, nil, nil, err
	}

	tapscriptAddress, err := builder.Address(params)
	if err != nil {
		return nil, nil, nil, nil, err
	}
	tapscriptData, err := builder.ToSign(0)
	if err != nil {
		return nil, nil, nil, nil, err
	}

	return tapscriptAddress, builder.GetInternalKey(), builder.GetMerkleRoot(), tapscriptData, nil
}

func scriptTweakBuilder(
	params *chaincfg.Params,
	internalKey *btcec.PublicKey,
	firstPublicKey *btcec.PublicKey,
) (*TapscriptBuilder, error) {
	timelockKeyScript, err := CreateTapscriptTimelockFromKey(params, int64(Timelock), firstPublicKey)
	if err != nil {
		return nil, err
	}

	return NewTapscriptBuilder(internalKey).
		AddLeafScript(timelockKeyScript), nil
}
