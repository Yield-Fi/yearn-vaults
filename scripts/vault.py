#!/usr/bin/3

from brownie import  accounts,config, Vault

btc_b = "0x152b9d0FdC40C096757F570A51E494bd4b943E50"
wAax = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7"
sAvax = "0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE"
weth = "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB"
usdc = "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E"

data = [
    [btc_b, "BTC.b"],
    [wAax, "WAVAX"],
    [sAvax, "sAVAX"],
    [weth, "WETH"],
    [usdc, "USDC"]
]

def main():
    acct = accounts.add(config["wallets"]["from_key"])
    print(f"address is {acct.address}")
    for token in data:
        vault = Vault.deploy({'from': acct})
        print(token[1], " vault deployed at ", vault.address)
        vault.initialize(
            token[0],
            token[1] +" Vault",
            "yfv-" + token[1],
            "0x73bD0A86836A0dec778C5e5AcDB6b71b24CA8f9f"
        )
        print("vault initialized")
        vault.setDepositLimit(2**256-1)
        print("deposit limit set")
