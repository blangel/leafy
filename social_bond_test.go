package leafy_test

import (
	"github.com/btcsuite/btcd/btcec/v2/schnorr"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/chaincfg"
	"github.com/btcsuite/btcd/txscript"
	"github.com/btcsuite/btcd/wire"
	"github.com/stretchr/testify/require"
	"leafy"
	"testing"
)

func TestSocialBond(t *testing.T) {
	// 2 wallets, 2 utxos
	_, userTxs, bitcoind, userFundingKey, _ := setupWallet(t)
	defer bitcoind.Cleanup()
	_, companionTxs, companionFundingKey, companionDestKey := createWallet(t, bitcoind)

	params := &chaincfg.RegressionNetParams

	// user provides recovery address
	recoveryScript, err := txscript.ParsePkScript(userTxs[0].TxOut[0].PkScript)
	require.NoError(t, err)

	// companion change
	companionChangeKey, err := companionDestKey.DeriveNextSibling()
	require.NoError(t, err)
	companionChangeInternalKey, err := companionChangeKey.GetPublicKey()
	require.NoError(t, err)
	companionChangeAddr, err := btcutil.NewAddressTaproot(schnorr.SerializePubKey(companionChangeInternalKey), params)
	require.NoError(t, err)
	companionChangeScript, err := txscript.PayToAddrScript(companionChangeAddr)

	// companion build social bond
	socialBondTx := &wire.MsgTx{
		Version:  2,
		LockTime: 0,
		TxIn: []*wire.TxIn{
			{
				PreviousOutPoint: wire.OutPoint{
					Hash:  companionTxs[0].TxHash(),
					Index: 0,
				},
				Sequence: 0,
			},
		},
		TxOut: []*wire.TxOut{
			{ // social-bond-utxo
				Value:    leafy.P2trDustAmt,
				PkScript: recoveryScript.Script(),
			},
			{ // social-bond-change (back to companion)
				Value:    companionTxs[0].TxOut[0].Value - (leafy.P2trDustAmt * 2), // TODO - fees via CPFP
				PkScript: companionChangeScript,
			},
		},
	}

	// recovery destination - TODO - new wallet? multi-sig of companions? fedimint? user selection of any of the previous?
	recoveryDestInternalKey, err := userFundingKey.GetPublicKey()
	require.NoError(t, err)
	recoveryDestAddr, err := btcutil.NewAddressTaproot(schnorr.SerializePubKey(recoveryDestInternalKey), params)
	require.NoError(t, err)
	recoveryDestScript, err := txscript.PayToAddrScript(recoveryDestAddr)

	// create recovery tx
	recoveryTx := &wire.MsgTx{
		Version:  2,
		LockTime: 0,
		TxIn: []*wire.TxIn{
			{
				PreviousOutPoint: wire.OutPoint{ // all user UTXOs for recovery
					Hash:  userTxs[0].TxHash(),
					Index: 0,
				},
				Sequence: 0,
			},
			{
				PreviousOutPoint: wire.OutPoint{
					Hash:  socialBondTx.TxHash(),
					Index: 0,
				},
				Sequence: 0,
			},
		},
		TxOut: []*wire.TxOut{
			{
				Value:    leafy.P2trDustAmt,
				PkScript: recoveryDestScript,
			},
			{
				Value:    companionTxs[0].TxOut[0].Value - (leafy.P2trDustAmt * 2), // TODO - fees via CPFP
				PkScript: recoveryScript.Script(),
			},
		},
	}
	prevOuts := make(map[wire.OutPoint]*wire.TxOut, 0)
	prevOuts[wire.OutPoint{
		Hash:  userTxs[0].TxHash(),
		Index: 0,
	}] = userTxs[0].TxOut[0]
	prevOuts[wire.OutPoint{
		Hash:  socialBondTx.TxHash(),
		Index: 0,
	}] = socialBondTx.TxOut[0]
	fetcher := txscript.NewMultiPrevOutFetcher(prevOuts)

	userFundingPrivateKey, err := userFundingKey.GetPrivateKey()
	require.NoError(t, err)
	userSigner := leafy.NewInMemorySigner(userFundingPrivateKey)
	witness, _, err := userSigner.TaprootSign(fetcher, recoveryTx, txscript.SigHashDefault, 0, nil)
	require.NoError(t, err)
	recoveryTx.TxIn[0].Witness = *witness

	witness, _, err = userSigner.TaprootSign(fetcher, recoveryTx, txscript.SigHashDefault, 1, nil)
	require.NoError(t, err)
	recoveryTx.TxIn[1].Witness = *witness

	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(recoveryTx, false)
	require.Error(t, err)
	require.Equal(t, "-25: bad-txns-inputs-missingorspent", err.Error())

	companionPrivateKey, err := companionFundingKey.GetPrivateKey()
	require.NoError(t, err)
	companionSigner := leafy.NewInMemorySigner(companionPrivateKey)
	socialBondFetcher := txscript.NewCannedPrevOutputFetcher(companionTxs[0].TxOut[0].PkScript, companionTxs[0].TxOut[0].Value)
	witness, _, err = companionSigner.TaprootSign(socialBondFetcher, socialBondTx, txscript.SigHashDefault, 0, nil)
	require.NoError(t, err)
	socialBondTx.TxIn[0].Witness = *witness
	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(socialBondTx, false)
	require.NoError(t, err)
	_, _, err = bitcoind.GetClient().MineToWalletFromImportedKeys(1)
	require.NoError(t, err)
	_, err = bitcoind.GetClient().RpcClient.SendRawTransaction(recoveryTx, false)
	require.NoError(t, err)
}
