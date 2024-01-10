package leafy_test

import (
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcec/v2/schnorr"
	"github.com/btcsuite/btcd/chaincfg/chainhash"
	"github.com/btcsuite/btcd/txscript"
	"github.com/btcsuite/btcd/wire"
	"github.com/stretchr/testify/require"
	"leafy"
	"testing"
)

func TestTaprootSign(t *testing.T) {
	privateKeyOne, err := btcec.NewPrivateKey()
	require.NoError(t, err)
	signer := leafy.NewInMemorySigner(privateKeyOne)

	// ensure signature uses tweaked key and appends SigHash
	msgTx, fetcher := generateMockMsgTx(t)
	sigHashType := txscript.SigHashAll
	inputIndex := 0
	witness, _, err := signer.TaprootSign(fetcher, msgTx, sigHashType, inputIndex, nil)
	require.NoError(t, err)
	require.Equal(t, 1, len(*witness))
	require.Equal(t, byte(sigHashType), (*witness)[0][len((*witness)[0])-1])

	expectedTweak := txscript.TweakTaprootPrivKey(*privateKeyOne, []byte{})
	sigHashes := txscript.NewTxSigHashes(msgTx, fetcher)
	sigHash, err := txscript.CalcTaprootSignatureHash(sigHashes, sigHashType, msgTx, inputIndex, fetcher)
	require.NoError(t, err)
	expectedSignature, err := schnorr.Sign(expectedTweak, sigHash)
	require.NoError(t, err)
	expectedWitness := append(expectedSignature.Serialize(), byte(sigHashType))
	require.EqualValues(t, expectedWitness, (*witness)[0])
}

func TestTapscriptSign(t *testing.T) {
	privateKeyOne, err := btcec.NewPrivateKey()
	require.NoError(t, err)
	signer := leafy.NewInMemorySigner(privateKeyOne)

	trueScript, err := txscript.NewScriptBuilder().AddOp(txscript.OP_TRUE).Script()
	require.NoError(t, err)
	timelock := int64(10)
	script, err := leafy.AugmentWithTimelock(timelock, trueScript)
	require.NoError(t, err)

	leafData, err := leafy.NewTapscriptBuilder(privateKeyOne.PubKey()).AddLeafScript(script).ToSign(0)
	require.NoError(t, err)

	msgTx, fetcher := generateMockMsgTx(t)
	sigHashType := txscript.SigHashDefault
	inputIndex := 0
	witness, _, err := signer.TapscriptSign(fetcher, msgTx, sigHashType, inputIndex, leafData)
	require.NoError(t, err)
	require.Equal(t, 3, len(*witness))
	require.EqualValues(t, leafData.Leaf.Script, (*witness)[1])
	require.EqualValues(t, leafData.ControlBlock, (*witness)[2])

	sigHashes := txscript.NewTxSigHashes(msgTx, fetcher)
	sigHash, err := txscript.CalcTapscriptSignaturehash(sigHashes, sigHashType, msgTx, inputIndex, fetcher, leafData.Leaf)
	require.NoError(t, err)
	tweakedPrivateKey := txscript.TweakTaprootPrivKey(*privateKeyOne, []byte{})
	expectedSignatureOne, err := schnorr.Sign(tweakedPrivateKey, sigHash)
	require.NoError(t, err)
	require.EqualValues(t, expectedSignatureOne.Serialize(), (*witness)[0])
}

func generateMockMsgTx(t *testing.T) (*wire.MsgTx, txscript.PrevOutputFetcher) {
	t.Helper()
	hash, err := chainhash.NewHash([]byte("23456789012345678901234567890123"))
	require.NoError(t, err)
	msgTx := &wire.MsgTx{
		Version:  2,
		LockTime: 0,
		TxIn: []*wire.TxIn{
			{
				PreviousOutPoint: wire.OutPoint{
					Hash:  *hash,
					Index: 0,
				},
				Sequence: 0,
			},
		},
		TxOut: []*wire.TxOut{
			{
				Value:    2000,
				PkScript: []byte{},
			},
		},
	}
	return msgTx, txscript.NewCannedPrevOutputFetcher([]byte{}, 3000)
}
