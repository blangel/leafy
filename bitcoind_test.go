package leafy_test

import (
	"encoding/json"
	"fmt"
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/chaincfg"
	"github.com/btcsuite/btcd/chaincfg/chainhash"
	"github.com/btcsuite/btcd/rpcclient"
	"github.com/btcsuite/btcd/wire"
	"leafy"
	rand2 "math/rand"
	"net"
	"os"
	"os/exec"
	"strings"
	"time"
)

type LocalBitcoinClient struct {
	client       *BitcoinClient
	cmd          *exec.Cmd
	tmpDirectory string
}

func StartLocalBitcoind(walletName string) (*LocalBitcoinClient, error) {
	tmpDirectory, err := os.MkdirTemp("", "bitcoind")
	if err != nil {
		return nil, err
	}

	rpcListen, err := net.Listen("tcp", ":0")
	if err != nil {
		err = os.RemoveAll(tmpDirectory)
		return nil, err
	}
	rpcPort := uint32(rpcListen.Addr().(*net.TCPAddr).Port)
	err = rpcListen.Close()
	if err != nil {
		return nil, err
	}

	const rpcUser = "test_rpc_user"
	const rpcPwd = "test_rpc_pwd"
	cmd := exec.Command(
		"bitcoind",
		"-server",
		"-regtest",
		"-txindex",
		"-listen=0",
		"-datadir="+tmpDirectory,
		"-rpcuser="+rpcUser,
		"-rpcpassword="+rpcPwd,
		fmt.Sprintf("-rpcport=%d", rpcPort),
	)
	if err := cmd.Start(); err != nil {
		_ = os.RemoveAll(tmpDirectory)
		return nil, err
	}
	client, err := NewBitcoinClient(&chaincfg.RegressionNetParams, walletName, "localhost", rpcPort, rpcUser, rpcPwd)

	if err != nil {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		_ = os.RemoveAll(tmpDirectory)
		return nil, err
	}
	return &LocalBitcoinClient{
		client:       client,
		cmd:          cmd,
		tmpDirectory: tmpDirectory,
	}, nil
}

func (c *LocalBitcoinClient) Cleanup() {
	_ = c.cmd.Process.Kill()
	_ = c.cmd.Wait()
	_ = os.RemoveAll(c.tmpDirectory)
}

func (c *LocalBitcoinClient) GetClient() *BitcoinClient {
	return c.client
}

type BitcoinClient struct {
	NetworkParams *chaincfg.Params
	RpcClient     *rpcclient.Client
}

type CreateWalletRequest struct {
	Name               string
	DisablePrivateKeys bool
	Blank              bool
	Passphrase         string
	AvoidReuse         bool
	Descriptors        bool
	LoadOnStartup      bool
	ExternalSigner     bool
}

type ImportDescriptorResult struct {
	Success  bool      `json:"success"`
	Warnings []string  `json:"warnings"`
	Error    *RpcError `json:"error"`
}

type RpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func NewBitcoinClient(
	networkParams *chaincfg.Params,
	walletName string,
	host string,
	port uint32,
	user string,
	pwd string,
) (*BitcoinClient, error) {
	fmt.Printf("connecting to bitcoin node: %v:******@%v:%v/wallet/%v\n", user, host, port, walletName)

	client, err := rpcclient.New(&rpcclient.ConnConfig{
		Host:         fmt.Sprintf("%v:%d/wallet/%v", host, port, walletName),
		User:         user,
		Pass:         pwd,
		Params:       networkParams.Name,
		DisableTLS:   true,
		HTTPPostMode: true,
	}, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to bitcoin node: %w", err)
	}

	return &BitcoinClient{
		NetworkParams: networkParams,
		RpcClient:     client,
	}, nil
}

func (b *BitcoinClient) CreateWallet(request *CreateWalletRequest) error {
	walletJson := wrapStringAsJson(request.Name)
	disablePrivateKeysJson := wrapBoolAsJson(request.DisablePrivateKeys)
	blankJson := wrapBoolAsJson(request.Blank)
	passphraseJson := wrapStringAsJson(request.Passphrase)
	avoidReuseJson := wrapBoolAsJson(request.AvoidReuse)
	descriptorsJson := wrapBoolAsJson(request.Descriptors)
	loadOnStartupJson := wrapBoolAsJson(request.LoadOnStartup)
	externalSignerJson := wrapBoolAsJson(request.ExternalSigner)
	_, err := b.RpcClient.RawRequest("createwallet",
		[]json.RawMessage{walletJson, disablePrivateKeysJson, blankJson, passphraseJson, avoidReuseJson, descriptorsJson,
			loadOnStartupJson, externalSignerJson})
	return err
}

func (b *BitcoinClient) ImportTaprootKeys(bip44Key *leafy.Bip44Key) error {
	return b.importTaprootKeysFromDescriptorWithoutChecksum(bip44Key.GetTaprootParentDescriptorWithoutChecksum("/*"))
}

func (b *BitcoinClient) GetTaprootAddressFromImportedKeys() (btcutil.Address, error) {
	label := "\"\""
	addressType := "\"bech32m\""
	result, err := b.RpcClient.RawRequest("getnewaddress", []json.RawMessage{[]byte(label), []byte(addressType)})
	if err != nil {
		return nil, err
	}
	var address string
	err = json.Unmarshal(result, &address)
	if err != nil {
		return nil, err
	}
	return btcutil.DecodeAddress(address, b.NetworkParams)
}

func (b *BitcoinClient) importTaprootKeysFromDescriptorWithoutChecksum(descriptor string) error {
	// will compute checksum of the descriptor
	descriptorInfo, err := b.RpcClient.GetDescriptorInfo(descriptor)
	if err != nil {
		return err
	}
	importDescriptorJson := fmt.Sprintf("[{\"desc\": \"%v\", \"timestamp\": \"now\", \"active\": true}]", descriptorInfo.Descriptor)
	jsonMsg := []byte(importDescriptorJson)
	result, err := b.RpcClient.RawRequest("importdescriptors", []json.RawMessage{jsonMsg})
	if err != nil {
		return err
	}
	var importDescriptorResults []ImportDescriptorResult
	err = json.Unmarshal(result, &importDescriptorResults)
	if err != nil {
		return err
	}
	if len(importDescriptorResults) > 0 && importDescriptorResults[0].Error != nil { // only importing one descriptor
		importError := importDescriptorResults[0].Error
		// ignore errors for those already imported
		if importError.Code == -8 && strings.HasPrefix(importError.Message, "new range") {
			fmt.Printf("descriptor already imported: %v", descriptorInfo.Descriptor)
		}
		return fmt.Errorf("failed to import descriptor %v | %v: %v",
			descriptorInfo.Descriptor, importError.Code, importError.Message)
	}
	return nil
}

func wrapStringAsJson(value string) []byte {
	return []byte(fmt.Sprintf("\"%v\"", value))
}

func wrapBoolAsJson(value bool) []byte {
	return []byte(fmt.Sprintf("%v", value))
}

func (b *BitcoinClient) MineToMaturity() ([]*chainhash.Hash, []*wire.MsgTx, error) {
	numberBlocks := b.NetworkParams.CoinbaseMaturity
	return b.MineToWalletFromImportedKeys(int64(numberBlocks))
}

func (b *BitcoinClient) MineToWalletFromImportedKeys(numberBlocks int64) ([]*chainhash.Hash, []*wire.MsgTx, error) {
	address, err := b.GetTaprootAddressFromImportedKeys()
	if err != nil {
		return nil, nil, err
	}
	return b.Mine(numberBlocks, address)
}

func (b *BitcoinClient) Mine(
	numberBlocks int64,
	to btcutil.Address,
) ([]*chainhash.Hash, []*wire.MsgTx, error) {
	fmt.Printf("mining %d blocks to %v\n", numberBlocks, to.EncodeAddress())
	hashes, err := b.RpcClient.GenerateToAddress(numberBlocks, to, nil)
	if err != nil {
		return nil, nil, err
	}
	if hashes == nil {
		backoff(fmt.Sprintf("failed to mine %d blocks", numberBlocks))
		return b.Mine(numberBlocks, to)
	}
	coinbaseTxs := make([]*wire.MsgTx, 0)
	// log coinbase of each hash
	for _, hash := range hashes {
		block, err := b.RpcClient.GetBlock(hash)
		if err != nil {
			backoff(fmt.Sprintf("failed to get mined block %v", hash.String()))
			return b.Mine(numberBlocks, to)
		}
		coinbaseTxHash := block.Transactions[0].TxHash()
		coinbaseTx, err := b.RpcClient.GetRawTransaction(&coinbaseTxHash)
		if err != nil {
			backoff(fmt.Sprintf("failed to get transaction %v from mined block %v", coinbaseTxHash.String(), block.BlockHash().String()))
			return b.Mine(numberBlocks, to)
		}
		coinbaseTxs = append(coinbaseTxs, coinbaseTx.MsgTx())
	}
	return hashes, coinbaseTxs, nil
}

func backoff(msg string) {
	rand := rand2.New(rand2.NewSource(time.Now().UnixNano()))
	pause := time.Duration(rand.Int31n(3)) * time.Second
	fmt.Printf("%v; backing off before retry for %v\n", msg, pause)
	time.Sleep(pause)
}
