#!/usr/bin/3

from brownie import  accounts,config, Registry

def main():
    # acct = accounts.load('9433e4ab2076978dbdd02903fdca3fd612810fdb6c69accb5b56c8d5fc4ce1de')
    # acct = accounts.add("9433e4ab2076978dbdd02903fdca3fd612810fdb6c69accb5b56c8d5fc4ce1de")
    acct = accounts.add(config["wallets"]["from_key"])
    registry = Registry.deploy({'from': acct})
    # return VaultConfig.deploy({'from': acct}, publish_source=True)