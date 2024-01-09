package leafy

import (
	"fmt"
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/btcutil/hdkeychain"
	"strconv"
	"strings"
)

type PathItem struct {
	path uint32
}

func (p *PathItem) getDerivationValue() string {
	pathValue := getPath(p.path)
	hardened := ""
	if isHardened(p.path) {
		hardened = "'"
	}
	return fmt.Sprintf("%d%v", pathValue, hardened)
}

func Path(path uint32) *PathItem {
	if isHardened(path) {
		return &PathItem{path: path - hdkeychain.HardenedKeyStart}
	}
	return &PathItem{path: path}
}

func PathHardened(path uint32) *PathItem {
	if isHardened(path) {
		return &PathItem{path: path}
	}
	return &PathItem{path: path + hdkeychain.HardenedKeyStart}
}

func (p *PathItem) Copy() *PathItem {
	return &PathItem{path: p.path}
}

func getPath(path uint32) uint32 {
	if path >= hdkeychain.HardenedKeyStart {
		return path - hdkeychain.HardenedKeyStart
	}
	return path
}

func isHardened(path uint32) bool {
	return path >= hdkeychain.HardenedKeyStart
}

type Bip44Key struct {
	changeKey   *hdkeychain.ExtendedKey
	indexKey    *hdkeychain.ExtendedKey
	fingerprint string
	purpose     *PathItem
	coin        *PathItem
	account     *PathItem
	change      *PathItem
	index       *PathItem
}

func CreateBip44Key(
	master *hdkeychain.ExtendedKey,
	purpose *PathItem,
	coin *PathItem,
	account *PathItem,
	change *PathItem,
	index *PathItem,
) (*Bip44Key, error) {
	masterEpub, err := master.Neuter()
	if err != nil {
		return nil, fmt.Errorf("invalid master: %v", err)
	}
	pubKey, err := masterEpub.ECPubKey()
	if err != nil {
		return nil, fmt.Errorf("invalid master epub: %v", err)
	}
	fingerprint := getFingerprint(pubKey)

	purposeKey, err := master.Derive(purpose.path)
	if err != nil {
		return nil, err
	}
	coinKey, err := purposeKey.Derive(coin.path)
	if err != nil {
		return nil, err
	}
	accountKey, err := coinKey.Derive(account.path)
	if err != nil {
		return nil, err
	}
	changeKey, err := accountKey.Derive(change.path)
	if err != nil {
		return nil, err
	}
	indexKey, err := changeKey.Derive(index.path)
	if err != nil {
		return nil, err
	}

	return &Bip44Key{
		changeKey:   changeKey,
		indexKey:    indexKey,
		fingerprint: fingerprint,
		purpose:     purpose,
		coin:        coin,
		account:     account,
		change:      change,
		index:       index,
	}, nil
}

func (b *Bip44Key) GetPublicKey() (*btcec.PublicKey, error) {
	return b.indexKey.ECPubKey()
}

func (b *Bip44Key) GetPrivateKey() (*btcec.PrivateKey, error) {
	return b.indexKey.ECPrivKey()
}

func (b *Bip44Key) GetPurposeRaw() uint32 {
	return b.purpose.path
}

func (b *Bip44Key) IsPurposeHardened() bool {
	return isHardened(b.purpose.path)
}

func (b *Bip44Key) GetPurpose() uint32 {
	return getPath(b.purpose.path)
}

func (b *Bip44Key) GetCoinRaw() uint32 {
	return b.coin.path
}

func (b *Bip44Key) IsCoinHardened() bool {
	return isHardened(b.coin.path)
}

func (b *Bip44Key) GetCoin() uint32 {
	return getPath(b.coin.path)
}

func (b *Bip44Key) GetAccountRaw() uint32 {
	return b.account.path
}

func (b *Bip44Key) IsAccountHardened() bool {
	return isHardened(b.account.path)
}

func (b *Bip44Key) GetAccount() uint32 {
	return getPath(b.account.path)
}

func (b *Bip44Key) GetChangeRaw() uint32 {
	return b.change.path
}

func (b *Bip44Key) IsChangeHardened() bool {
	return isHardened(b.change.path)
}

func (b *Bip44Key) GetChange() uint32 {
	return getPath(b.change.path)
}

func (b *Bip44Key) GetIndexRaw() uint32 {
	return b.index.path
}

func (b *Bip44Key) IsIndexHardened() bool {
	return isHardened(b.index.path)
}

func (b *Bip44Key) GetIndex() uint32 {
	return getPath(b.index.path)
}

func (b *Bip44Key) GetFingerprint() string {
	return b.fingerprint
}

func ImportFromTaprootDescriptorForParentWithoutChecksum(
	descriptor string,
	index *PathItem,
) (*Bip44Key, error) {
	if !strings.HasPrefix(descriptor, "tr([") {
		return nil, fmt.Errorf("invalid tr descriptor; expecting prefix 'tr([' but was %v", descriptor)
	}
	fingerprint := descriptor[4:12]
	endIndex := strings.Index(descriptor, "]")
	derivationPath := descriptor[13:endIndex]
	derivations := strings.Split(derivationPath, "/")
	if len(derivations) != 4 {
		return nil, fmt.Errorf("invalid tr descriptor; expecting derivations up through bip-44 change but was %v", derivationPath)
	}
	purpose, err := parsePath(derivations[0], "purpose")
	coin, err := parsePath(derivations[1], "coin")
	account, err := parsePath(derivations[2], "account")
	change, err := parsePath(derivations[3], "change")

	changeEpub := descriptor[endIndex+1 : len(descriptor)-1]
	changeKey, err := hdkeychain.NewKeyFromString(changeEpub)
	if err != nil {
		return nil, err
	}
	indexKey, err := changeKey.Derive(index.path)
	if err != nil {
		return nil, err
	}
	return &Bip44Key{
		changeKey:   changeKey,
		indexKey:    indexKey,
		fingerprint: fingerprint,
		purpose:     purpose,
		coin:        coin,
		account:     account,
		change:      change,
		index:       index,
	}, nil
}

func parsePath(pathDerivation string, derivationLevel string) (*PathItem, error) {
	var path *PathItem
	if strings.HasSuffix(pathDerivation, "'") {
		pathVal, err := strconv.ParseUint(pathDerivation[0:len(pathDerivation)-1], 10, 32)
		if err != nil {
			return nil, fmt.Errorf("could not parse %s path: %w", derivationLevel, err)
		}
		path = PathHardened(uint32(pathVal))
	} else {
		pathVal, err := strconv.ParseUint(pathDerivation, 10, 32)
		if err != nil {
			return nil, fmt.Errorf("could not parse %s path: %w", derivationLevel, err)
		}
		path = Path(uint32(pathVal))
	}
	return path, nil
}

func (b *Bip44Key) GetTaprootDescriptorForParentWithoutChecksum(suffixDerivation string) string {
	if !strings.HasPrefix(suffixDerivation, "/") && (len(suffixDerivation) != 0) {
		suffixDerivation = fmt.Sprintf("/%s", suffixDerivation)
	}
	epub, err := b.changeKey.Neuter()
	if err != nil {
		panic(err) // should not occur
	}
	return fmt.Sprintf("tr([%s/%s]%s)", b.GetFingerprint(), b.GetParentDerivation(), epub.String())
}

func (b *Bip44Key) GetTaprootDescriptorWithoutChecksum(suffixDerivation string) string {
	if !strings.HasPrefix(suffixDerivation, "/") && (len(suffixDerivation) != 0) {
		suffixDerivation = fmt.Sprintf("/%s", suffixDerivation)
	}
	epub, err := b.indexKey.Neuter()
	if err != nil {
		panic(err) // should not occur
	}
	return fmt.Sprintf("tr([%s/%s]%s%s)", b.GetFingerprint(), b.GetDerivation(), epub.String(), suffixDerivation)
}

func (b *Bip44Key) GetTaprootParentDescriptorWithoutChecksum(suffixDerivation string) string {
	if !strings.HasPrefix(suffixDerivation, "/") && (len(suffixDerivation) != 0) {
		suffixDerivation = fmt.Sprintf("/%s", suffixDerivation)
	}
	epub, err := b.changeKey.Neuter()
	if err != nil {
		panic(err) // should not occur
	}
	return fmt.Sprintf("tr([%s/%s]%s%s)", b.GetFingerprint(), b.GetParentDerivation(), epub.String(), suffixDerivation)
}

func (b *Bip44Key) GetDerivation() string {
	return fmt.Sprintf("%v/%v", b.GetParentDerivation(), b.index.getDerivationValue())
}

func (b *Bip44Key) GetParentDerivation() string {
	return fmt.Sprintf("%v/%v/%v/%v", b.purpose.getDerivationValue(),
		b.coin.getDerivationValue(), b.account.getDerivationValue(), b.change.getDerivationValue())
}

func (b *Bip44Key) DeriveNextSibling() (*Bip44Key, error) {
	siblingIndex := Path(b.index.path + 1)
	if isHardened(b.index.path) {
		siblingIndex = PathHardened(b.index.path + 1)
	}
	sibling, err := b.changeKey.Derive(siblingIndex.path)
	if err != nil {
		return nil, err
	}
	return &Bip44Key{
		changeKey:   b.changeKey,
		indexKey:    sibling,
		fingerprint: b.fingerprint,
		purpose:     b.purpose.Copy(),
		coin:        b.coin.Copy(),
		account:     b.account.Copy(),
		change:      b.change.Copy(),
		index:       siblingIndex,
	}, nil
}

func (b *Bip44Key) CopyWithNewMaster(master *hdkeychain.ExtendedKey) (*Bip44Key, error) {
	masterEpub, err := master.Neuter()
	if err != nil {
		return nil, fmt.Errorf("invalid master: %v", err)
	}
	pubKey, err := masterEpub.ECPubKey()
	if err != nil {
		return nil, fmt.Errorf("invalid master epub: %v", err)
	}
	fingerprint := getFingerprint(pubKey)

	purposeKey, err := master.Derive(b.purpose.path)
	if err != nil {
		return nil, err
	}
	coinKey, err := purposeKey.Derive(b.coin.path)
	if err != nil {
		return nil, err
	}
	accountKey, err := coinKey.Derive(b.account.path)
	if err != nil {
		return nil, err
	}
	changeKey, err := accountKey.Derive(b.change.path)
	if err != nil {
		return nil, err
	}
	indexKey, err := changeKey.Derive(b.index.path)
	if err != nil {
		return nil, err
	}

	return &Bip44Key{
		changeKey:   changeKey,
		indexKey:    indexKey,
		fingerprint: fingerprint,
		purpose:     b.purpose.Copy(),
		coin:        b.coin.Copy(),
		account:     b.account.Copy(),
		change:      b.change.Copy(),
		index:       b.index.Copy(),
	}, nil
}

// see [BIP-32 fingerprint](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#user-content-Key_identifiers)
func getFingerprint(epub *btcec.PublicKey) string {
	epubHash160 := btcutil.Hash160(epub.SerializeCompressed())
	return fmt.Sprintf("%x", epubHash160[0:4])
}
