package leafy

import (
	"encoding/hex"
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcec/v2/schnorr"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/chaincfg"
	"github.com/btcsuite/btcd/chaincfg/chainhash"
	"github.com/btcsuite/btcd/txscript"
	"github.com/btcsuite/btcd/wire"
	"time"
)

type Utxo struct {
	FromAddress string
	Outpoint    wire.OutPoint
	Amount      int64
	Script      string
}

type SpentInput struct {
	Witness [][]byte
}

func (u *Utxo) DecodeScript() ([]byte, error) {
	decodedScript, err := hex.DecodeString(u.Script)
	if err != nil {
		return nil, err
	}
	return decodedScript, nil
}

func TimelockToApproximateDuration(timelock int64) time.Duration {
	return time.Minute * time.Duration(10) * time.Duration(timelock)
}

func GetTaprootAddress(publicKey *btcec.PublicKey, params *chaincfg.Params) (*btcutil.AddressTaproot, error) {
	return btcutil.NewAddressTaproot(schnorr.SerializePubKey(txscript.ComputeTaprootKeyNoScript(publicKey)), params)
}

// Inscribe puts 'data' into an [inscription-like](https://docs.ordinals.com/inscriptions.html) script wrapper
func Inscribe(data []byte) ([]byte, error) {
	scriptBuilder := txscript.NewScriptBuilder().
		AddOp(txscript.OP_FALSE).
		AddOp(txscript.OP_IF)
	splits := splitForInscription(data)
	for _, split := range splits {
		scriptBuilder.AddData(split)
	}
	scriptBuilder.AddOp(txscript.OP_ENDIF)
	return scriptBuilder.Script()
}

func splitForInscription(data []byte) [][]byte {
	var splits [][]byte
	for i := 0; i < len(data); i += txscript.MaxScriptElementSize {
		end := i + txscript.MaxScriptElementSize
		if end > len(data) {
			end = len(data)
		}
		splits = append(splits, data[i:end])
	}
	return splits
}

type TapscriptLeafScript []byte
type TapscriptControlBlock []byte

type TapscriptSigningData struct {
	Leaf         txscript.TapLeaf
	LeafScript   TapscriptLeafScript
	ControlBlock TapscriptControlBlock
	MerkleRoot   chainhash.Hash
}

type TapscriptBuilder struct {
	leaves      []txscript.TapLeaf
	internalKey *btcec.PublicKey
}

func NewTapscriptBuilder(internalKey *btcec.PublicKey) *TapscriptBuilder {
	return &TapscriptBuilder{
		leaves:      make([]txscript.TapLeaf, 0),
		internalKey: internalKey,
	}
}

func (t *TapscriptBuilder) AddLeafScript(script []byte) *TapscriptBuilder {
	leaf := txscript.NewBaseTapLeaf(script)
	leaves := append(t.leaves, leaf)
	t.leaves = leaves
	return t
}

func (t *TapscriptBuilder) Address(params *chaincfg.Params) (btcutil.Address, error) {
	tree := txscript.AssembleTaprootScriptTree(t.leaves...)
	treeRootHash := tree.RootNode.TapHash()
	outputKey := txscript.ComputeTaprootOutputKey(t.internalKey, treeRootHash[:])
	return btcutil.NewAddressTaproot(schnorr.SerializePubKey(outputKey), params)
}

func (t *TapscriptBuilder) Script(params *chaincfg.Params) (TapscriptLeafScript, error) {
	outputAddr, err := t.Address(params)
	if err != nil {
		return nil, err
	}
	return txscript.PayToAddrScript(outputAddr)
}

func (t *TapscriptBuilder) ToSign(leafIndex int) (*TapscriptSigningData, error) {
	tree := txscript.AssembleTaprootScriptTree(t.leaves...)
	controlBlock := tree.LeafMerkleProofs[leafIndex].ToControlBlock(t.internalKey)
	controlBlockBytes, err := controlBlock.ToBytes()
	if err != nil {
		return nil, err
	}
	return &TapscriptSigningData{
		Leaf:         tree.LeafMerkleProofs[leafIndex].TapLeaf,
		LeafScript:   tree.LeafMerkleProofs[leafIndex].Script,
		ControlBlock: controlBlockBytes,
		MerkleRoot:   tree.RootNode.TapHash(),
	}, nil
}

func (t *TapscriptBuilder) GetMerkleRoot() []byte {
	tree := txscript.AssembleTaprootScriptTree(t.leaves...)
	root := tree.RootNode.TapHash()
	return root[:]
}

func (t *TapscriptBuilder) GetInternalKey() *btcec.PublicKey {
	return t.internalKey
}

func (t *TapscriptBuilder) GetTapLeaves() []txscript.TapLeaf {
	return t.leaves
}

func CreateTapscriptTimelockFromKey(params *chaincfg.Params, timelock int64, publicKey *btcec.PublicKey) ([]byte, error) {
	address, err := GetTaprootAddress(publicKey, params)
	if err != nil {
		return nil, err
	}
	// create the "v:pk(key)" of "and_v(v:pk(key),older(timelock))"
	hashScript, err := txscript.NewScriptBuilder().
		AddData(address.ScriptAddress()).
		AddOp(txscript.OP_CHECKSIGVERIFY).
		Script()
	if err != nil {
		return nil, err
	}
	// create the "older(timelock)" of "and_v(v:pk(key),older(timelock))"
	return AugmentWithTimelock(timelock, hashScript)
}

func AugmentWithTimelock(timelock int64, script []byte) ([]byte, error) {
	timelockScript, err := txscript.NewScriptBuilder().
		AddInt64(timelock).
		AddOp(txscript.OP_CHECKSEQUENCEVERIFY).
		Script()
	if err != nil {
		return nil, err
	}
	return append(script, timelockScript...), nil
}
