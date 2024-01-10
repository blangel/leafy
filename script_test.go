package leafy_test

import (
	"crypto/sha256"
	"encoding/binary"
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcutil/base58"
	"github.com/btcsuite/btcd/btcutil/hdkeychain"
	"github.com/btcsuite/btcd/chaincfg"
	"github.com/btcsuite/btcd/txscript"
	"github.com/stretchr/testify/require"
	"leafy"
	"testing"
	"time"
)

const (
	privateKey = "5Le3tS2RgQgab5ejXqP7VSE7ripRUX8CPAoLSewJy77P"
)

func TestTimelockToApproximateDuration(t *testing.T) {
	duration := leafy.TimelockToApproximateDuration(1)
	require.EqualValues(t, time.Minute*10, duration)

	duration = leafy.TimelockToApproximateDuration(144)
	require.EqualValues(t, time.Minute*10*144, duration)
}

func TestGetTaprootAddress(t *testing.T) {
	decoded := base58.Decode(privateKey)
	_, publicKey := btcec.PrivKeyFromBytes(decoded)

	address, err := leafy.GetTaprootAddress(publicKey, &chaincfg.RegressionNetParams)
	require.NoError(t, err)
	require.EqualValues(t, "bcrt1p04duxvckpglw0ea2h3p6qkfjxep3897v9jxrgc520rya4fsjg9csqqry6y", address.EncodeAddress())
}

func TestCreateTapscriptTimelockFromKey(t *testing.T) {
	params := &chaincfg.RegressionNetParams
	seed, err := hdkeychain.GenerateSeed(hdkeychain.RecommendedSeedLen)
	require.NoError(t, err)
	master, err := hdkeychain.NewMaster(seed, &chaincfg.RegressionNetParams)
	require.NoError(t, err)
	destKey, err := leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.Path(0),
		leafy.Path(0))
	require.NoError(t, err)

	timelock := 52560
	destKey, err = destKey.DeriveNextSibling()
	require.NoError(t, err)
	destPublicKey, err := destKey.GetPublicKey()
	require.NoError(t, err)
	destPrivateKey, err := destKey.GetPrivateKey()
	require.NoError(t, err)
	hash := sha256.Sum256(destPrivateKey.Serialize())
	tweakedDestPublicKey := txscript.ComputeTaprootOutputKey(destPublicKey, hash[:])

	timelockHashScript, err := leafy.CreateTapscriptTimelockFromKey(params, int64(timelock), destPublicKey)
	builder := leafy.NewTapscriptBuilder(tweakedDestPublicKey).AddLeafScript(timelockHashScript)
	addr, err := builder.Address(params)
	require.NoError(t, err)
	addrScript, err := builder.Script(params)
	require.NoError(t, err)
	scriptFromAddr, err := txscript.PayToAddrScript(addr)
	require.NoError(t, err)
	require.EqualValues(t, addrScript, scriptFromAddr)
}

func TestAugmentWithTimelock(t *testing.T) {
	params := chaincfg.RegressionNetParams
	privateKey, err := btcec.NewPrivateKey()
	require.NoError(t, err)

	addr, err := leafy.GetTaprootAddress(privateKey.PubKey(), &params)
	require.NoError(t, err)

	timelock := int64(5)
	addrScript, err := txscript.NewScriptBuilder().AddData(addr.ScriptAddress()).AddOp(txscript.OP_CHECKSIGVERIFY).Script()
	require.NoError(t, err)
	augmentedScript, err := leafy.AugmentWithTimelock(timelock, addrScript)
	require.NoError(t, err)
	verifyEndCSV(t, augmentedScript, txscript.OP_5)
	require.EqualValues(t, txscript.OP_CHECKSIGVERIFY, augmentedScript[len(augmentedScript)-3])
	require.EqualValues(t, addr.ScriptAddress(), augmentedScript[1:len(augmentedScript)-3])
	require.EqualValues(t, txscript.OP_DATA_32, augmentedScript[0])
}

func TestInscribe(t *testing.T) {
	// zero-length
	result, err := leafy.Inscribe([]byte{})
	require.NoError(t, err)
	require.Equal(t, 3, len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[2])
	// one-length (with known op-code)
	result, err = leafy.Inscribe([]byte{0x1})
	require.NoError(t, err)
	require.Equal(t, 4, len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(txscript.OP_1), result[2])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[3])
	// one-length (with unknown op-code)
	result, err = leafy.Inscribe([]byte{0x1A})
	require.NoError(t, err)
	require.Equal(t, 5, len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(0x1), result[2]) // size of data p
	require.Equal(t, uint8(0x1A), result[3])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[4])
	// one-length, -1
	result, err = leafy.Inscribe([]byte{0x81})
	require.NoError(t, err)
	require.Equal(t, 4, len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(txscript.OP_1NEGATE), result[2]) // size of data p
	require.Equal(t, uint8(txscript.OP_ENDIF), result[3])
	// one-length (with unknown op-code)
	result, err = leafy.Inscribe([]byte{0x1A})
	require.NoError(t, err)
	require.Equal(t, 5, len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(0x1), result[2]) // size of data p
	require.Equal(t, uint8(0x1A), result[3])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[4])
	// one-length (with OP_DATA_1 type)
	result, err = leafy.Inscribe([]byte{17})
	require.NoError(t, err)
	require.Equal(t, 5, len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(txscript.OP_DATA_1), result[2]) // size of data p
	require.Equal(t, uint8(17), result[3])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[4])
	// OP_PUSHDATA1 case
	data := []byte{}
	for i := 0; i < txscript.OP_PUSHDATA1+1; i++ {
		data = append(data, uint8(i))
	}
	result, err = leafy.Inscribe(data)
	require.NoError(t, err)
	require.Equal(t, 5+len(data), len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(txscript.OP_PUSHDATA1), result[2])
	require.Equal(t, uint8(len(data)), result[3])
	require.Equal(t, data[0], result[4])
	require.Equal(t, data[len(data)-1], result[3+len(data)])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[4+len(data)])
	// OP_PUSHDATA2 case
	data = []byte{}
	for i := 0; i < 0xff+1; i++ {
		data = append(data, uint8(i))
	}
	result, err = leafy.Inscribe(data)
	require.NoError(t, err)
	require.Equal(t, 6+len(data), len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	require.Equal(t, uint8(txscript.OP_PUSHDATA2), result[2])
	dataBuf := make([]byte, 2)
	binary.LittleEndian.PutUint16(dataBuf, uint16(len(data)))
	require.Equal(t, dataBuf[0], result[3])
	require.Equal(t, dataBuf[1], result[4])
	require.Equal(t, data[0], result[5])
	require.Equal(t, data[len(data)-1], result[4+len(data)])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[5+len(data)])
	// Note, OP_PUSHDATA4 case exceeds txscript.MaxScriptElementSize && txscript.MaxScriptSize
	// handle (txscript.MaxScriptSize-4) splits
	data = []byte{}
	for i := 0; i < txscript.MaxScriptSize-4-(20*3); i++ {
		data = append(data, uint8(i))
	}
	result, err = leafy.Inscribe(data)
	require.NoError(t, err)
	require.Equal(t, 61+len(data), len(result))
	require.Equal(t, uint8(txscript.OP_FALSE), result[0])
	require.Equal(t, uint8(txscript.OP_IF), result[1])
	dataBuf = make([]byte, 4)
	binary.LittleEndian.PutUint16(dataBuf, uint16(txscript.MaxScriptElementSize))
	index := 2
	for i := 0; i < 19; i++ {
		require.Equal(t, uint8(txscript.OP_PUSHDATA2), result[index])
		index++
		require.Equal(t, dataBuf[0], result[index])
		index++
		require.Equal(t, dataBuf[1], result[index])
		index++
		require.Equal(t, data[i*txscript.MaxScriptElementSize], result[index])
		index += txscript.MaxScriptElementSize - 1
		require.Equal(t, data[(txscript.MaxScriptElementSize-1)+(i*txscript.MaxScriptElementSize)],
			result[index])
		index++
	}
	require.Equal(t, uint8(txscript.OP_DATA_56), result[index])
	index++
	require.Equal(t, data[19*txscript.MaxScriptElementSize], result[index])
	index += txscript.OP_DATA_56 - 1
	require.Equal(t, data[len(data)-1], result[index])
	require.Equal(t, uint8(txscript.OP_ENDIF), result[index+1])
}

func verifyEndCSV(t *testing.T, csvScript []byte, timelockOp byte) {
	require.EqualValues(t, txscript.OP_CHECKSEQUENCEVERIFY, csvScript[len(csvScript)-1])
	require.EqualValues(t, timelockOp, csvScript[len(csvScript)-2])
}
