import pytest
import brownie

FEE_MAX = 10_000


def test_performance_fees(gov, vault, token, TestStrategy, rewards, strategist, chain, vault_config, partner):
    vault_config.updateManagementFee(vault.address, 0, {"from": gov})
    vault_config.updatePerformanceFee(vault.address, 450, {"from": gov})
    vault_config.updatePartnerFee(vault.address, 0, {"from": partner})

    strategy = strategist.deploy(TestStrategy, vault)
    vault.addStrategy(strategy, 2_000, 1000, 1000, 50, {"from": gov})

    assert vault.balanceOf(rewards) == 0
    assert vault.balanceOf(strategy) == 0

    token.transfer(strategy, 10 ** token.decimals(), {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})

    assert vault.balanceOf(rewards) == 0.045 * 10 ** token.decimals()
    assert vault.balanceOf(strategy) == 0.005 * 10 ** token.decimals()

def test_partner_fees(gov, vault, token, TestStrategy, rewards, partner, strategist, chain, vault_config):
    vault_config.updateManagementFee(vault.address, 0, {"from": gov})
    vault_config.updatePerformanceFee(vault.address, 0, {"from": gov})
    vault_config.updatePartnerFee(vault.address, 1000, {"from": partner})

    strategy = strategist.deploy(TestStrategy, vault)
    vault.addStrategy(strategy, 2_000, 1000, 1000, 0, {"from": gov})

    assert vault.balanceOf(rewards) == 0
    assert vault.balanceOf(strategy) == 0

    token.transfer(strategy, 10 ** token.decimals(), {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})

    assert vault.balanceOf(partner) == 0.10 * 10 ** token.decimals()
    assert vault.balanceOf(rewards) == 0
    assert vault.balanceOf(strategy) == 0


def test_zero_fees(gov, vault, token, TestStrategy, rewards, partner, strategist, chain, vault_config):
    vault_config.updateManagementFee(vault.address, 0, {"from": gov})
    vault_config.updatePerformanceFee(vault.address, 0, {"from": gov})
    vault_config.updatePartnerFee(vault.address, 0, {"from": partner})

    strategy = strategist.deploy(TestStrategy, vault)
    vault.addStrategy(strategy, 2_000, 1000, 1000, 0, {"from": gov})

    assert vault.balanceOf(rewards) == 0
    assert vault.balanceOf(strategy) == 0

    token.transfer(strategy, 10 ** token.decimals(), {"from": gov})
    chain.sleep(1)
    strategy.harvest({"from": strategist})

    assert vault_config.getManagementFee(vault.address) == 0
    assert vault_config.getPerformanceFee(vault.address) == 0
    assert vault.strategies(strategy).dict()["performanceFee"] == 0
    assert vault.balanceOf(rewards) == 0
    assert vault.balanceOf(strategy) == 0
    assert vault.balanceOf(partner) == 0


def test_max_fees(gov, vault, token, TestStrategy, rewards, strategist, vault_config):
    # performance fee should not be higher than MAX
    vault_config.updatePerformanceFee(vault.address, FEE_MAX / 2, {"from": gov})
    with brownie.reverts():
        vault_config.updatePerformanceFee(vault.address, FEE_MAX / 2 + 1, {"from": gov})

    # management fee should not be higher than MAX
    vault_config.updateManagementFee(vault.address, FEE_MAX, {"from": gov})


    with brownie.reverts():
        vault_config.updateManagementFee(vault.address, FEE_MAX + 1, {"from": gov})

    # addStrategy should check for MAX FEE
    strategy = strategist.deploy(TestStrategy, vault)
    with brownie.reverts():
        vault.addStrategy(strategy, 2_000, 1000, 1000, FEE_MAX / 2 + 1, {"from": gov})

    # updateStrategyPerformanceFee should check for max to be MAX FEE / 2
    vault.addStrategy(strategy, 2_000, 1000, 1000, FEE_MAX / 2, {"from": gov})
    vault_performance_fee = vault_config.getPerformanceFee(vault.address)
    with brownie.reverts():
        vault.updateStrategyPerformanceFee(strategy, FEE_MAX / 2 + 1, {"from": gov})

    # updateStrategyPerformanceFee should check for max to be MAX FEE / 2
    vault_config.updatePerformanceFee(vault.address, 0, {"from": gov})

    vault.updateStrategyPerformanceFee(strategy, FEE_MAX / 2, {"from": gov})
    with brownie.reverts():
        vault.updateStrategyPerformanceFee(strategy, FEE_MAX / 2 + 1, {"from": gov})


def test_delegated_fees(chain, rewards, vault, strategy, gov, token, vault_config):
    # Make sure funds are in the strategy
    chain.sleep(1)
    strategy.harvest()
    assert strategy.estimatedTotalAssets() > 0

    # Make sure that no performance fees are charged
    vault_config.updatePerformanceFee(vault.address, 0, {"from": gov})
    vault.updateStrategyPerformanceFee(strategy, 0, {"from": gov})

    # Management fee is active...
    bal_before = vault.balanceOf(rewards)
    chain.mine(timedelta=60 * 60 * 24 * 365)  # Mine a year at 2% mgmt fee
    token.transfer(strategy, 10 ** token.decimals())
    strategy.harvest()
    assert vault.balanceOf(rewards) > bal_before  # increase in mgmt fees

    # Check delegation math/logic
    strategy._toggleDelegation()
    assert strategy.delegatedAssets() == vault.strategies(strategy).dict()["totalDebt"]

    # Delegated assets pay no fees (everything is delegated now)
    bal_before = vault.balanceOf(rewards)
    chain.mine(timedelta=60 * 60 * 24 * 365)  # Mine a year at 0% mgmt fee
    token.transfer(strategy, 10 ** token.decimals())
    strategy.harvest()
    assert vault.balanceOf(rewards) == bal_before  # No increase in mgmt fees


def test_gain_less_than_fees(chain, rewards, vault, strategy, gov, token, vault_config):
    chain.sleep(1)
    # Make sure funds are in the strategy
    strategy.harvest()
    assert strategy.estimatedTotalAssets() > 0

    token.transfer(strategy, 10 ** token.decimals())

    # Governance and strategist have not earned any fees yet
    assert vault.balanceOf(rewards) == 0
    assert vault.balanceOf(strategy) == 0

    # Performance fees set to standard 10%
    vault_config.updatePerformanceFee(vault.address, 1000, {"from": gov})
    vault.updateStrategyPerformanceFee(strategy, 1000, {"from": gov})
    chain.mine(timedelta=60 * 60 * 24 * 365)  # Mine a year at 2% mgmt fee
    price_per_share_before = vault.pricePerShare()
    strategy.harvest()

    # Share price should not have changed because 100% of profit goes too fees. No more no less
    # Price per share has not changed but rewards have been distributed to rewards and strategy
    assert vault.pricePerShare() == price_per_share_before
    assert vault.balanceOf(rewards) > 0
    assert vault.balanceOf(strategy) > 0
