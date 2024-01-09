package leafy_test

import (
	"github.com/btcsuite/btcd/btcutil/hdkeychain"
	"github.com/btcsuite/btcd/chaincfg"
	"github.com/stretchr/testify/require"
	"leafy"
	"testing"
)

const (
	masterSeed            = "tprv8ZgxMBicQKsPejd9UGTpgTRvMNzMeQuAfTm5eKtdrZartR1r6vVieEAvKMboCM6DqUiMGwL3dzRjZfkJ1ukZpZotVCuJSiutnybFq3AHB3e"
	masterSeedFingerprint = "d33e9597"
)

func TestDerivation(t *testing.T) {
	seed, err := hdkeychain.GenerateSeed(hdkeychain.MaxSeedBytes)
	require.NoError(t, err)
	master, err := hdkeychain.NewMaster(seed, &chaincfg.RegressionNetParams)
	require.NoError(t, err)
	bip44Key, err := leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.Path(0),
		leafy.Path(0))
	require.NoError(t, err)
	derivation := bip44Key.GetDerivation()
	require.EqualValues(t, "44'/0'/0'/0/0", derivation)

	sibling, err := bip44Key.DeriveNextSibling()
	require.NoError(t, err)
	derivation = sibling.GetDerivation()
	require.EqualValues(t, "44'/0'/0'/0/1", derivation)

	// all hardened
	bip44Key, err = leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.PathHardened(0))
	require.NoError(t, err)
	derivation = bip44Key.GetDerivation()
	require.EqualValues(t, "44'/0'/0'/0'/0'", derivation)

	sibling, err = bip44Key.DeriveNextSibling()
	require.NoError(t, err)
	derivation = sibling.GetDerivation()
	require.EqualValues(t, "44'/0'/0'/0'/1'", derivation)
}

func TestFingerprint(t *testing.T) {
	master, err := hdkeychain.NewKeyFromString(masterSeed)
	require.NoError(t, err)
	bip44Key, err := leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.Path(0),
		leafy.Path(0))
	require.NoError(t, err)

	require.Equal(t, masterSeedFingerprint, bip44Key.GetFingerprint())

	descriptor := bip44Key.GetTaprootDescriptorWithoutChecksum("")
	require.Equal(t, "tr([d33e9597/44'/0'/0'/0/0]tpubDGVRNRd2zdf4dNNuy5AU8JLFGVSQw2SfFFLJcHjSFyFvBCjQCArQHXuhxAhispWsja1UT2K5DNqtvF8v8JaNfdUhuVk5rfBBjBPd5pddrzp)", descriptor)

	bip44Key, err = leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(1),
		leafy.Path(0),
		leafy.Path(256))
	require.NoError(t, err)

	require.Equal(t, masterSeedFingerprint, bip44Key.GetFingerprint())
	require.Equal(t, "44'/0'/1'/0/256", bip44Key.GetDerivation())
}

func TestGetTaprootDescriptorWithoutChecksum(t *testing.T) {
	master, err := hdkeychain.NewKeyFromString(masterSeed)
	require.NoError(t, err)
	bip44Key, err := leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.Path(0),
		leafy.Path(0))
	require.NoError(t, err)

	require.Equal(t, masterSeedFingerprint, bip44Key.GetFingerprint())

	descriptor := bip44Key.GetTaprootDescriptorWithoutChecksum("")
	require.Equal(t, "tr([d33e9597/44'/0'/0'/0/0]tpubDGVRNRd2zdf4dNNuy5AU8JLFGVSQw2SfFFLJcHjSFyFvBCjQCArQHXuhxAhispWsja1UT2K5DNqtvF8v8JaNfdUhuVk5rfBBjBPd5pddrzp)", descriptor)

	descriptor = bip44Key.GetTaprootDescriptorWithoutChecksum("*")
	require.Equal(t, "tr([d33e9597/44'/0'/0'/0/0]tpubDGVRNRd2zdf4dNNuy5AU8JLFGVSQw2SfFFLJcHjSFyFvBCjQCArQHXuhxAhispWsja1UT2K5DNqtvF8v8JaNfdUhuVk5rfBBjBPd5pddrzp/*)", descriptor)
}

func TestImportFromTaprootDescriptorForParentWithoutChecksum(t *testing.T) {
	master, err := hdkeychain.NewKeyFromString(masterSeed)
	require.NoError(t, err)
	bip44Key, err := leafy.CreateBip44Key(master,
		leafy.PathHardened(44),
		leafy.PathHardened(0),
		leafy.PathHardened(0),
		leafy.Path(0),
		leafy.Path(0))
	require.NoError(t, err)

	changeEpub := bip44Key.GetTaprootParentDescriptorWithoutChecksum("")
	require.Equal(t, "tr([d33e9597/44'/0'/0'/0]tpubDFaA4bycWtPHMKZMdF85Pr1tK1m7fft4B6B8LtbVUWSAZnvYXL4pvsyKT1e8TXyduZR1tpjLJBsPRgia6YmQA95D25a6ptyNq9kKqHVNXFp)", changeEpub)

	deserialBip44Key, err := leafy.ImportFromTaprootDescriptorForParentWithoutChecksum(changeEpub, leafy.Path(0))
	require.NoError(t, err)

	serialChangeEpub := deserialBip44Key.GetTaprootParentDescriptorWithoutChecksum("")
	require.Equal(t, changeEpub, serialChangeEpub)
}
