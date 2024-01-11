package leafy_test

import (
	"encoding/hex"
	"fmt"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/btcutil/hdkeychain"
	"github.com/btcsuite/btcd/chaincfg"
	"github.com/btcsuite/btcd/chaincfg/chainhash"
	"github.com/btcsuite/btcd/txscript"
	"github.com/btcsuite/btcd/wire"
	"github.com/stretchr/testify/require"
	"github.com/tyler-smith/go-bip39"
	"leafy"
	"math/rand"
	"strings"
	"testing"
	"time"
)

const (
	seedMnemonic = "post since achieve cause begin wonder rice sail dad arrange medal dignity poverty puzzle goat banner receive ill poem expand soup attend head dice"
)

func TestGetAddresses(t *testing.T) {
	params := &chaincfg.RegressionNetParams
	// boundary check
	_, err := leafy.GetAddresses(params, leafy.NewWallet("", ""), 0, 0)
	require.Errorf(t, err, "invalid amount to generate [%d], must be greater than 0", 0)

	wallet := leafy.NewWallet(seedMnemonic, seedMnemonic)

	addresses, err := leafy.GetAddresses(params, wallet, 0, 2)
	require.NoError(t, err)
	require.Equal(t, 2, len(addresses))
	require.Equal(t, "bcrt1pfncurwja7y8d628x85vua4zlcjm08w6mgkt4uyk0xadm739ku72shr4wzp", addresses[0])
	require.Equal(t, "bcrt1pe3r5e5ey3masltdr6yc7deczhv3dnlhzeduz80qsq7htld4ywyyqn3u8jm", addresses[1])

	descriptor, err := leafy.GetDescriptor(params, seedMnemonic)
	require.NoError(t, err)
	recoveryWallet := leafy.NewRecoveryWallet(seedMnemonic, descriptor)
	addresses, err = leafy.GetAddresses(params, recoveryWallet, 0, 2)
	require.NoError(t, err)
	require.Equal(t, 2, len(addresses))
	require.Equal(t, "bcrt1pfncurwja7y8d628x85vua4zlcjm08w6mgkt4uyk0xadm739ku72shr4wzp", addresses[0])
	require.Equal(t, "bcrt1pe3r5e5ey3masltdr6yc7deczhv3dnlhzeduz80qsq7htld4ywyyqn3u8jm", addresses[1])
}

func TestCreateAndSignTransaction(t *testing.T) {
	wallet, txs, bitcoind, fundingKey, _ := setupWallet(t)
	defer bitcoind.Cleanup()

	params := &chaincfg.RegressionNetParams
	addresses, err := leafy.GetAddresses(params, wallet, 1, 4)
	destAddress1, err := btcutil.DecodeAddress(addresses[0], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)
	destAddress2, err := btcutil.DecodeAddress(addresses[1], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)
	destAddress3, err := btcutil.DecodeAddress(addresses[2], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)
	destAddress4, err := btcutil.DecodeAddress(addresses[3], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)

	lockScript1, err := txscript.PayToAddrScript(destAddress1)
	require.NoError(t, err)
	lockScript2, err := txscript.PayToAddrScript(destAddress2)
	require.NoError(t, err)
	fundingMsg := createMsgTx(txs[0], 1000, lockScript1, lockScript2)
	fundingPrivateKey, err := fundingKey.GetPrivateKey()
	require.NoError(t, err)
	fundingSigner := leafy.NewInMemorySigner(fundingPrivateKey)
	fundingFetcher := txscript.NewCannedPrevOutputFetcher(txs[0].TxOut[0].PkScript, txs[0].TxOut[0].Value)
	witness, _, err := fundingSigner.TaprootSign(fundingFetcher, fundingMsg, txscript.SigHashDefault, 0, nil)
	require.NoError(t, err)
	fundingMsg.TxIn[0].Witness = *witness

	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(fundingMsg, false)
	require.NoError(t, err)
	_, _, err = bitcoind.GetClient().MineToWalletFromImportedKeys(1)
	require.NoError(t, err)

	// spend from default key path
	utxos := make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		FromAddress: destAddress1.EncodeAddress(),
		Outpoint: wire.OutPoint{
			Hash:  fundingMsg.TxHash(),
			Index: 0,
		},
		Amount: fundingMsg.TxOut[0].Value,
		Script: hex.EncodeToString(fundingMsg.TxOut[0].PkScript),
	})
	utxos = append(utxos, leafy.Utxo{
		FromAddress: destAddress2.EncodeAddress(),
		Outpoint: wire.OutPoint{
			Hash:  fundingMsg.TxHash(),
			Index: 1,
		},
		Amount: fundingMsg.TxOut[1].Value,
		Script: hex.EncodeToString(fundingMsg.TxOut[1].PkScript),
	})
	signedMsg, err := leafy.CreateAndSignTransaction(params, wallet, utxos, destAddress3, destAddress4, 1000, 20)
	require.NoError(t, err)

	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(signedMsg.Msg, false)
	require.NoError(t, err)
}

func TestCreateAndSignRecoveryTransaction(t *testing.T) {
	leafy.Timelock = 10
	wallet, txs, bitcoind, fundingKey, _ := setupWallet(t)
	defer bitcoind.Cleanup()
	defer func() { leafy.Timelock = leafy.DefaultTimelock }()

	params := &chaincfg.RegressionNetParams
	addresses, err := leafy.GetAddresses(params, wallet, 1, 4)
	destAddress1, err := btcutil.DecodeAddress(addresses[0], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)
	destAddress2, err := btcutil.DecodeAddress(addresses[1], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)
	destAddress3, err := btcutil.DecodeAddress(addresses[2], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)
	destAddress4, err := btcutil.DecodeAddress(addresses[3], bitcoind.GetClient().NetworkParams)
	require.NoError(t, err)

	lockScript1, err := txscript.PayToAddrScript(destAddress1)
	require.NoError(t, err)
	lockScript2, err := txscript.PayToAddrScript(destAddress2)
	require.NoError(t, err)
	fundingMsg := createMsgTx(txs[0], 1000, lockScript1, lockScript2)
	fundingPrivateKey, err := fundingKey.GetPrivateKey()
	require.NoError(t, err)
	fundingSigner := leafy.NewInMemorySigner(fundingPrivateKey)
	fundingFetcher := txscript.NewCannedPrevOutputFetcher(txs[0].TxOut[0].PkScript, txs[0].TxOut[0].Value)
	witness, _, err := fundingSigner.TaprootSign(fundingFetcher, fundingMsg, txscript.SigHashDefault, 0, nil)
	require.NoError(t, err)
	fundingMsg.TxIn[0].Witness = *witness

	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(fundingMsg, false)
	require.NoError(t, err)
	_, _, err = bitcoind.GetClient().MineToWalletFromImportedKeys(1)
	require.NoError(t, err)

	// extract utxos for spend
	utxos := make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		FromAddress: destAddress1.EncodeAddress(),
		Outpoint: wire.OutPoint{
			Hash:  fundingMsg.TxHash(),
			Index: 0,
		},
		Amount: fundingMsg.TxOut[0].Value,
		Script: hex.EncodeToString(fundingMsg.TxOut[0].PkScript),
	})
	utxos = append(utxos, leafy.Utxo{
		FromAddress: destAddress2.EncodeAddress(),
		Outpoint: wire.OutPoint{
			Hash:  fundingMsg.TxHash(),
			Index: 1,
		},
		Amount: fundingMsg.TxOut[1].Value,
		Script: hex.EncodeToString(fundingMsg.TxOut[1].PkScript),
	})

	// ensure timelock on tapscript[0]
	signedMsg, err := leafy.CreateAndSignRecoveryTransaction(params, wallet, utxos, destAddress3, destAddress4, 1000, 20)
	require.NoError(t, err)
	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(signedMsg.Msg, false)
	require.Error(t, err)
	require.True(t, strings.Contains(err.Error(), "-26: non-BIP68-final"))

	// advance up to timelock
	_, _, err = bitcoind.GetClient().MineToWalletFromImportedKeys(int64(leafy.Timelock - 2))
	require.NoError(t, err)
	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(signedMsg.Msg, false)
	require.Error(t, err)
	require.True(t, strings.Contains(err.Error(), "-26: non-BIP68-final"))

	// advance past timelock, should now be able to spend
	_, _, err = bitcoind.GetClient().MineToWalletFromImportedKeys(1)
	require.NoError(t, err)

	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(signedMsg.Msg, false)
	require.NoError(t, err)
}

func TestCreateTransaction(t *testing.T) {
	// invalid destination address
	addr, err := btcutil.DecodeAddress("bcrt1pkm32th8q6qhhnx5l5qmf7v3s29fsdsytl5h69c05chgz9mf4yl2qwnyzzk", &chaincfg.RegressionNetParams)
	require.NoError(t, err)
	mockAddr := &mockAddress{}
	_, err = leafy.CreateTransaction(nil, addr, mockAddr, 0, 0)
	require.Error(t, err)
	// invalid change address
	_, err = leafy.CreateTransaction(nil, mockAddr, addr, 0, 0)
	require.Error(t, err)

	// invalid fee rate
	_, err = leafy.CreateTransaction(nil, addr, addr, 101, -1)
	require.Error(t, err)
	require.EqualValues(t, "invalid fee rate; should be >= 0", err.Error())
	_, err = leafy.CreateTransaction(nil, addr, addr, 101, 0)
	require.Error(t, err)
	require.EqualValues(t, "invalid fee rate; should be >= 0", err.Error())

	// insufficient funds; prior to fee
	utxos := make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 0,
		},
		Amount: 100,
	})
	_, err = leafy.CreateTransaction(utxos, addr, addr, 101, 1)
	require.Error(t, err)
	require.EqualValues(t, "insufficient funds; need 101 have 100", err.Error())

	// insufficient funds; once including fee
	_, err = leafy.CreateTransaction(utxos, addr, addr, 90, 1)
	require.Error(t, err)
	require.EqualValues(t, "insufficient funds to account for fees; need 101 have 0 remaining", err.Error())

	// match of amount with fees and change
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 1000,
	})
	tx, err := leafy.CreateTransaction(utxos, addr, addr, 100, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 2, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 2, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1100), tx.TxInputAmt)
	require.EqualValues(t, int64(111), tx.TxFeeAmt)
	require.EqualValues(t, int64(889), tx.TxChangeAmt)
	require.False(t, tx.IsChangeDust())

	// exact match of amount and fees, i.e. no change [selection of utxo is first match, put exact match first]
	utxos = make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 0,
		},
		Amount: 211,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 1000,
	})
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 100, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 1, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 1, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(211), tx.TxInputAmt)
	require.EqualValues(t, int64(111), tx.TxFeeAmt)
	require.EqualValues(t, int64(0), tx.TxChangeAmt)
	require.False(t, tx.IsChangeDust())

	// spend-all case
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 0, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 2, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 1, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1211), tx.TxInputAmt)
	require.EqualValues(t, int64(169), tx.TxFeeAmt)
	require.EqualValues(t, int64(0), tx.TxChangeAmt)
	require.False(t, tx.IsChangeDust())
	// spend-all with 1 UTXO
	utxos = make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 1000,
	})
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 0, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 1, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 1, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1000), tx.TxInputAmt)
	require.EqualValues(t, int64(111), tx.TxFeeAmt)
	require.EqualValues(t, int64(0), tx.TxChangeAmt)
	require.False(t, tx.IsChangeDust())

	// exactly dust amount remaining
	utxos = make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 100,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 1000,
	})
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 601, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 2, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 2, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1100), tx.TxInputAmt)
	require.EqualValues(t, int64(169), tx.TxFeeAmt) // 931
	require.EqualValues(t, int64(330), tx.TxChangeAmt)
	require.True(t, tx.IsChangeDust())
	// under dust amount
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 700, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 2, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 2, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1100), tx.TxInputAmt)
	require.EqualValues(t, int64(169), tx.TxFeeAmt) // 931
	require.EqualValues(t, int64(231), tx.TxChangeAmt)
	require.True(t, tx.IsChangeDust())
	// dust but one more input alleviates
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 2,
		},
		Amount: 400,
	})
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 700, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 3, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 2, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1500), tx.TxInputAmt)
	require.EqualValues(t, int64(169), tx.TxFeeAmt) // 931
	require.EqualValues(t, int64(631), tx.TxChangeAmt)
	require.False(t, tx.IsChangeDust())
	// dust but more inputs needed to alleviate
	utxos = make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 100,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 1000,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 2,
		},
		Amount: 200,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 3,
		},
		Amount: 200,
	})
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 850, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 4, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 2, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1500), tx.TxInputAmt)
	require.EqualValues(t, int64(169), tx.TxFeeAmt) // 931
	require.EqualValues(t, int64(481), tx.TxChangeAmt)
	require.False(t, tx.IsChangeDust())
	// dust, add more inputs but still dust
	utxos = make([]leafy.Utxo, 0)
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 100,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 1,
		},
		Amount: 1000,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 2,
		},
		Amount: 20,
	})
	utxos = append(utxos, leafy.Utxo{
		Outpoint: wire.OutPoint{
			Hash:  chainhash.DoubleHashH([]byte("foo bar")),
			Index: 3,
		},
		Amount: 20,
	})
	tx, err = leafy.CreateTransaction(utxos, addr, addr, 850, 1)
	require.NoError(t, err)
	require.NotNil(t, tx.Hex)
	require.NotNil(t, tx.MsgTx)
	require.EqualValues(t, 4, len(tx.MsgTx.TxIn))
	require.EqualValues(t, 2, len(tx.MsgTx.TxOut))
	require.EqualValues(t, int64(1140), tx.TxInputAmt)
	require.EqualValues(t, int64(169), tx.TxFeeAmt) // 931
	require.EqualValues(t, int64(121), tx.TxChangeAmt)
	require.True(t, tx.IsChangeDust())
}

func TestCreateEphemeralSocialKeyPair(t *testing.T) {
	pair, err := leafy.CreateEphemeralSocialKeyPair()
	require.NoError(t, err)
	require.NotNil(t, pair.PrivateKey)
	require.NotNil(t, pair.PublicKey)
}

func TestValidateEphemeralSocialPublicKey(t *testing.T) {
	pair, err := leafy.CreateEphemeralSocialKeyPair()
	require.NoError(t, err)
	err = leafy.ValidateEphemeralSocialPublicKey(pair.PublicKey)
	require.NoError(t, err)
	// invalid case
	err = leafy.ValidateEphemeralSocialPublicKey("not a public key")
	require.Error(t, err)
}

func TestEncryptAndDecryptWithEphemeralSocialPublicKeyAndPrivateKey(t *testing.T) {
	pair, err := leafy.CreateEphemeralSocialKeyPair()
	require.NoError(t, err)
	message := "foo bar"
	encrypted, err := leafy.EncryptWithEphemeralSocialPublicKey(pair.PublicKey, message)
	require.NoError(t, err)
	decrypted, err := leafy.DecryptWithEphemeralSocialPrivateKey(pair.PrivateKey, encrypted)
	require.NoError(t, err)
	require.EqualValues(t, message, decrypted)

	_, err = leafy.EncryptWithEphemeralSocialPublicKey("not a public key", message)
	require.Error(t, err)
	encrypted, err = leafy.EncryptWithEphemeralSocialPublicKey(pair.PublicKey, message)
	require.NoError(t, err)
	_, err = leafy.DecryptWithEphemeralSocialPrivateKey("not a private key", encrypted)
	require.Error(t, err)

	// 301 bytes of data
	message = "A quick brown fox, known for its remarkable agility, jumps over a lazy dog resting under the warm sunshine, beside a serene river flowing through a lush forest, bustling with diverse wildlife, echoing with melodious bird songs, creating a picturesque, tranquil, and utterly captivating scene in nature"
	encrypted, err = leafy.EncryptWithEphemeralSocialPublicKey(pair.PublicKey, message)
	require.NoError(t, err)
	decrypted, err = leafy.DecryptWithEphemeralSocialPrivateKey(pair.PrivateKey, encrypted)
	require.NoError(t, err)
	require.EqualValues(t, message, decrypted)
}

func setupWallet(t *testing.T) (leafy.Wallet, []*wire.MsgTx, *LocalBitcoinClient, *leafy.Bip44Key, *leafy.Bip44Key) {
	randomGenerator := rand.New(rand.NewSource(time.Now().UnixNano()))
	walletName := fmt.Sprintf("leafy-unittests-%d", randomGenerator.Int())
	bitcoind, err := StartLocalBitcoind(walletName)
	require.NoError(t, err)
	err = bitcoind.GetClient().CreateWallet(&CreateWalletRequest{
		Name:               walletName,
		DisablePrivateKeys: true,
		Descriptors:        true,
	})
	require.NoError(t, err)

	wallet, txs, fundingKey, destKey := createWallet(t, bitcoind)
	return wallet, txs, bitcoind, fundingKey, destKey
}

func createWallet(t *testing.T, bitcoind *LocalBitcoinClient) (leafy.Wallet, []*wire.MsgTx, *leafy.Bip44Key, *leafy.Bip44Key) {
	wallet, err := leafy.CreateNewWallet()
	require.NoError(t, err)

	seed, err := bip39.EntropyFromMnemonic(wallet.GetFirstMnemonic())
	require.NoError(t, err)
	master, err := hdkeychain.NewMaster(seed, &chaincfg.RegressionNetParams)
	fundingKey, err := leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.Path(0),
		leafy.Path(0))
	require.NoError(t, err)
	destKey1, err := fundingKey.DeriveNextSibling()
	require.NoError(t, err)

	err = bitcoind.GetClient().ImportTaprootKeys(fundingKey)
	require.NoError(t, err)

	_, txs, err := bitcoind.GetClient().MineToWalletFromImportedKeys(1)
	require.NoError(t, err)
	_, _, err = bitcoind.GetClient().MineToMaturity()
	require.NoError(t, err)

	return wallet, txs, fundingKey, destKey1
}

func createMsgTx(from *wire.MsgTx, feeAmount int64, outputScripts ...[]byte) *wire.MsgTx {
	msg := &wire.MsgTx{
		Version:  2,
		LockTime: 0,
		TxIn: []*wire.TxIn{
			{
				PreviousOutPoint: wire.OutPoint{
					Hash:  from.TxHash(),
					Index: 0,
				},
				Sequence: 0,
			},
		},
		TxOut: []*wire.TxOut{},
	}
	for _, script := range outputScripts {
		fee := feeAmount / int64(len(outputScripts))
		value := (from.TxOut[0].Value / int64(len(outputScripts))) - fee
		msg.TxOut = append(msg.TxOut, &wire.TxOut{
			Value:    value,
			PkScript: script,
		})
	}
	return msg
}

type mockAddress struct{}

func (b *mockAddress) EncodeAddress() string {
	return ""
}
func (b *mockAddress) ScriptAddress() []byte {
	return nil
}
func (b *mockAddress) IsForNet(chainParams *chaincfg.Params) bool {
	return true // why not?
}
func (b *mockAddress) String() string {
	return ""
}
