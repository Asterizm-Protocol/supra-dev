# Supra asterizm project

## Install Supra 

1.  Install supra [cli](https://docs.supra.com/move/getting-started/supra-cli-with-docker).

```bash
mkdir -p ~/supra/configs/move_workspace
docker run --name supra_cli -v ~/supra/configs:/supra/configs -e SUPRA_HOME=/supra/configs --net=host -itd asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v6.3.0
```

2.  Create supra [key](https://docs.supra.com/move/getting-started/generate-key-profiles) - it will be your address.

```bash
supra key generate-profile test
```

3.  Get faucet [tokens](https://docs.supra.com/move/getting-started/testnet-faucet).

```bash
supra move account fund-with-faucet --account 0x63b211deaf0406e190ae88e305d4d5ecd57801e90bf03d23f8ca77eaf1bac62c --url https://rpc-testnet.supra.com
```

4. Compile

```bash
supra move tool compile --package-dir /supra/configs/move_workspace/asterizm
```

5. Test

```bash
supra move tool test --package-dir /supra/configs/move_workspace/asterizm
```
