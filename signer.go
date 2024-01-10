package leafy

import (
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcec/v2/schnorr"
	"github.com/btcsuite/btcd/txscript"
	"github.com/btcsuite/btcd/wire"
)

type Signer interface {
	// TaprootSign will sign input at 'inputIndex' using the provided 'sigHashType'
	TaprootSign(
		fetcher txscript.PrevOutputFetcher,
		tx *wire.MsgTx,
		sigHashType txscript.SigHashType,
		inputIndex int,
		merkleRoot []byte) (*wire.TxWitness, []byte, error)
	// TapscriptSign will sign input at 'inputIndex' for the given 'leafData' using the provided 'sigHashType'
	TapscriptSign(
		fetcher txscript.PrevOutputFetcher,
		tx *wire.MsgTx,
		sigHashType txscript.SigHashType,
		inputIndex int,
		leafData *TapscriptSigningData) (*wire.TxWitness, []byte, error)
}

type SignatureType uint64

const (
	Bare SignatureType = iota
	NoScript
	Script
)

type SignType struct {
	signatureType SignatureType
	merkleRoot    []byte
}

func (s *SignType) GetSignatureType() SignatureType {
	return s.signatureType
}

func (s *SignType) GetMerkleRoot() []byte {
	return s.merkleRoot
}

func BareSignType() *SignType {
	return &SignType{
		signatureType: Bare,
		merkleRoot:    nil,
	}
}

func NoScriptSignType() *SignType {
	return &SignType{
		signatureType: NoScript,
		merkleRoot:    []byte{},
	}
}

func ScriptSignType(merkleRoot []byte) *SignType {
	return &SignType{
		signatureType: Script,
		merkleRoot:    merkleRoot,
	}
}

type InMemorySigner struct {
	privateKey *btcec.PrivateKey
}

func NewInMemorySigner(privateKey *btcec.PrivateKey) *InMemorySigner {
	return &InMemorySigner{
		privateKey: privateKey,
	}
}

func (p *InMemorySigner) sign(message []byte, signType *SignType) (*schnorr.Signature, error) {
	return schnorr.Sign(p.getTweakedPrivateKey(signType), message)
}

func (p *InMemorySigner) getTweakedPrivateKey(signType *SignType) *btcec.PrivateKey {
	tweakedPrivateKey := p.privateKey
	switch signType.GetSignatureType() {
	case NoScript:
		tweakedPrivateKey = txscript.TweakTaprootPrivKey(*tweakedPrivateKey, []byte{})
	case Script:
		tweakedPrivateKey = txscript.TweakTaprootPrivKey(*tweakedPrivateKey, signType.GetMerkleRoot())
	}
	return tweakedPrivateKey
}

func (s *InMemorySigner) TaprootSign(
	fetcher txscript.PrevOutputFetcher,
	tx *wire.MsgTx,
	sigHashType txscript.SigHashType,
	inputIndex int,
	merkleRoot []byte,
) (*wire.TxWitness, []byte, error) {
	sigHash, err := computeTaprootSigHash(fetcher, tx, sigHashType, inputIndex)
	if err != nil {
		return nil, nil, err
	}
	signType := NoScriptSignType()
	if merkleRoot != nil {
		signType = ScriptSignType(merkleRoot)
	}
	signature, err := s.sign(sigHash, signType)
	if err != nil {
		return nil, nil, err
	}
	if sigHashType == txscript.SigHashDefault {
		return &wire.TxWitness{signature.Serialize()}, sigHash, nil
	}
	signatureWithHashType := append(signature.Serialize(), byte(sigHashType))
	return &wire.TxWitness{signatureWithHashType}, sigHash, nil
}

func (s *InMemorySigner) TapscriptSign(
	fetcher txscript.PrevOutputFetcher,
	tx *wire.MsgTx,
	sigHashType txscript.SigHashType,
	inputIndex int,
	leafData *TapscriptSigningData,
) (*wire.TxWitness, []byte, error) {
	sigHash, err := computeTapscriptSigHash(fetcher, tx, sigHashType, inputIndex, leafData.Leaf)
	if err != nil {
		return nil, nil, err
	}
	signature, err := s.sign(sigHash, NoScriptSignType())
	if err != nil {
		return nil, nil, err
	}
	return &wire.TxWitness{
		signature.Serialize(),
		leafData.LeafScript,
		leafData.ControlBlock,
	}, sigHash, nil
}

func computeTaprootSigHash(
	fetcher txscript.PrevOutputFetcher,
	tx *wire.MsgTx,
	sigHashType txscript.SigHashType,
	inputIndex int,
) ([]byte, error) {
	sigHashes := txscript.NewTxSigHashes(tx, fetcher)
	return txscript.CalcTaprootSignatureHash(sigHashes, sigHashType, tx, inputIndex, fetcher)
}

func computeTapscriptSigHash(
	fetcher txscript.PrevOutputFetcher,
	tx *wire.MsgTx,
	sigHashType txscript.SigHashType,
	inputIndex int,
	leaf txscript.TapLeaf,
) ([]byte, error) {
	sigHashes := txscript.NewTxSigHashes(tx, fetcher)
	return txscript.CalcTapscriptSignaturehash(sigHashes, sigHashType, tx, inputIndex, fetcher, leaf)
}
