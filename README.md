# Leafy 🌿

Leafy is a Bitcoin wallet designed to be user-friendly. It is built for individuals interested in Bitcoin but with little to no knowledge of how Bitcoin works.

* **Easy to use** - Leafy creates interactions which are familiar to users, matching expectations from their other applications. Users need not understand Bitcoin technicalities to interact with the application.
* **Serverless** - Leafy has no servers. All components and data of Leafy are controlled by the user. 
* **Self custodial** - Leafy provides complete control of users' bitcoin to the users themselves.
* **Easy to recover** - Leafy is robust to multiple types of disaster scenarios. It optimizes for ease of recovery for common user loss scenarios (i.e. user loses phone).
* **Secure** - Leafy utilizes best practices and multiple Bitcoin primitives to secure users' funds.
* **User scalable** - Leafy is built to allow for simple onboarding of users to Bitcoin but then scales in features as the user learns more about the Bitcoin ecosystem.
* **(Optionally) Social** - Leafy provides certain services (like [wallet recovery](#TBD) and [bitcoin trading](#TBD)) via the help of a users' trusted set of social companions.

## Intended Audience

Individuals who want to participate in Bitcoin via [self-custody](#self-custody) but do not want to undertake the learning curve, cost and hassle required by other solutions. The user experience of Leafy matches the ease of utilizing a custodial system (like an exchange) while still being self-custodial.

## Additional Topics

Additional topics, either unlikely or advanced, are discussed below.

### Bitcoin Network Connectivity

Leafy does not require users to [run a full bitcoin node](https://river.com/learn/how-to-run-a-bitcoin-node/). This is purposefully done to ease onboarding and the burden on the user when using the application. For connectivity to the Bitcoin network, Leafy leverages the open source [mempool.space APIs](https://mempool.space/docs/api/rest).

#### Customizable Bitcoin Network Connectivity

For those interested, Leafy makes it easy to "upgrade" a user's usage of Leafy to control how the application accesses the Bitcoin network. Leafy does this by allowing the user to modify the mempool.space API URL used by the application. This allows the user to run a self-hosted/local version of the open source mempool.space application (mempool.space [documents this process](https://github.com/mempool/mempool/tree/master/docker)) in conjunction with their own full bitcoin node. This optional configuration allows for better [self-sovereignty](#self-sovereign) of the user's bitcoin.

## Terminology

### Self Custody

Self custody means the user financially owning bitcoin also owns the responsibility of the bitcoin's encumbrance. Typically, bitcoin is encumbered via a locking script which solely requires the possession of a private key. Often self-custody is synonymous with possession of a private key. However, bitcoin can be encumbered in simpler as well as more complicated ways than a single or set of private key(s). To be self-custodial the user must take responsibility for the full encumbrance (be it private keys, preimages, etc) of their bitcoin.

### Self Sovereign

Leafy views 