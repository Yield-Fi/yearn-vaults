#!/usr/bin/3

from brownie import  accounts,config, VaultConfig

def main():
    acct = accounts.add(config["wallets"]["from_key"])
    print(f"address is {acct.address}")
    vaultConfig = VaultConfig.deploy({'from': acct}, publish_source=True)
    print(f"vault config deployed at {vaultConfig.address}")
    vaultConfig.config(
        acct.address, # partner
        acct.address, # management
        acct.address, # guardian
        acct.address, # rewards
        acct.address # approver
    )
    print("vaultConfig configured")
    # verify()
    # # return VaultConfig.deploy({'from': acct}, publish_source=True)
    
def verify():
    vaultConfig = VaultConfig.at("0xbC3Ef30c430069158A42a469cd74FbEeBBc4Ddb6")
    VaultConfig.publish_source(vaultConfig)
    print("verified")