import pytest
import brownie
from brownie import ZERO_ADDRESS
from contextlib import contextmanager
from brownie import chain

@pytest.fixture
def vault(gov, token, Vault, liquidator):
    # NOTE: Overriding the one in conftest because it has values already
    vault = gov.deploy(Vault)
    vault.initialize(
        token, gov, gov, token.symbol() + " yVault", "yv" + token.symbol(), gov
    )
    vault.setDepositLimit(2**256 - 1, {"from": gov})
    vault.setLiquidator(liquidator, {"from": gov})

    yield vault


def test_deposit_and_liquidate(gov, vault, token, liquidator):
    balance = token.balanceOf(gov)
    token.approve(vault, balance, {"from": gov})
    vault.deposit(balance // 2, {"from": gov})

    assert vault.liquidator() == liquidator
    assert token.balanceOf(vault) == balance // 2
    assert vault.totalDebt() == 0
    assert vault.pricePerShare() == 10 ** token.decimals()  # 1:1 price

    # Do it twice to test behavior when it has shares
    vault.deposit({"from": gov})

    assert vault.totalSupply() == token.balanceOf(vault) == balance
    assert vault.totalDebt() == 0
    assert vault.pricePerShare() == 10 ** token.decimals()  # 1:1 price

    # Can't liquidate as gov has't allowed liquidations 
    with brownie.reverts():
        vault.liquidate(vault.balanceOf(gov), gov, {"from": liquidator})


    # Gov sets liquidation allowance to total balance 
    vault.adjustLiquidationRequest(vault.balanceOf(gov),  {"from": gov})
    assert vault.pendingLiquidatons(gov) == vault.balanceOf(gov)


    vault.liquidate(vault.balanceOf(gov), gov, {"from": liquidator})
    assert vault.pendingLiquidatons(gov) == 0 
    assert vault.totalSupply() == token.balanceOf(vault) == 0
    assert vault.totalDebt() == 0
    assert token.balanceOf(gov) == balance


def test_deposit_and_revoked_liquidate(gov, vault, token, liquidator):
    balance = token.balanceOf(gov)
    token.approve(vault, balance, {"from": gov})
    vault.deposit(balance // 2, {"from": gov})

    assert vault.liquidator() == liquidator
    assert token.balanceOf(vault) == balance // 2
    assert vault.totalDebt() == 0
    assert vault.pricePerShare() == 10 ** token.decimals()  # 1:1 price

    # Do it twice to test behavior when it has shares
    vault.deposit({"from": gov})

    assert vault.totalSupply() == token.balanceOf(vault) == balance
    assert vault.totalDebt() == 0
    assert vault.pricePerShare() == 10 ** token.decimals()  # 1:1 price

    # Can't liquidate as gov has't allowed liquidations 
    with brownie.reverts():
        vault.liquidate(vault.balanceOf(gov), gov, {"from": liquidator})


    # Gov sets liquidation allowance to total balance 
    vault.adjustLiquidationRequest(vault.balanceOf(gov),  {"from": gov})
    assert vault.pendingLiquidatons(gov) == vault.balanceOf(gov)

    chain.mine(5)
    chain.sleep(5)

    vault.adjustLiquidationRequest(0,  {"from": gov})

    with brownie.reverts():
        vault.liquidate(vault.balanceOf(gov), gov, {"from": liquidator})

    assert vault.pendingLiquidatons(gov) == 0 
