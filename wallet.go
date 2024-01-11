package leafy

import "github.com/btcsuite/btcd/chaincfg"

type RecoveryWallet interface {
	GetFirstMnemonic() string
	GetSecondDescriptor(*chaincfg.Params) (string, error)
}

type Wallet interface {
	RecoveryWallet
	GetSecondMnemonic() string
}

type normalWallet struct {
	firstMnemonic  string
	secondMnemonic string
}

func (w *normalWallet) GetFirstMnemonic() string {
	return w.firstMnemonic
}

func (w *normalWallet) GetSecondDescriptor(params *chaincfg.Params) (string, error) {
	return GetDescriptor(params, w.secondMnemonic)
}

func (w *normalWallet) GetSecondMnemonic() string {
	return w.secondMnemonic
}

func NewWallet(firstMnemonic, secondMnemonic string) Wallet {
	return &normalWallet{
		firstMnemonic:  firstMnemonic,
		secondMnemonic: secondMnemonic,
	}
}

type recoveryWallet struct {
	firstMnemonic    string
	secondDescriptor string
}

func (w *recoveryWallet) GetFirstMnemonic() string {
	return w.firstMnemonic
}

func (w *recoveryWallet) GetSecondDescriptor(_ *chaincfg.Params) (string, error) {
	return w.secondDescriptor, nil
}

func NewRecoveryWallet(firstMnemonic, secondDescriptor string) RecoveryWallet {
	return &recoveryWallet{
		firstMnemonic:    firstMnemonic,
		secondDescriptor: secondDescriptor,
	}
}

// CreateNewWallet creates two hdkeychain.RecommendedSeedLen length seeds and their associated BIP-39 mnemonics.
func CreateNewWallet() (Wallet, error) {
	first, err := GenerateMnemonic()
	if err != nil {
		return nil, err
	}
	second, err := GenerateMnemonic()
	if err != nil {
		return nil, err
	}
	return NewWallet(first, second), nil
}
