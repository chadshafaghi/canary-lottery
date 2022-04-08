import pytest
import time
from brownie import CanariLottery, accounts, config, network, exceptions
from web3 import Web3
from scripts.deploy_lottery import deploy_lottery
from scripts.helpful_scripts import (
    get_account,
    get_contract,
    is_local_env,
    fund_with_link,
)


def test_can_pick_winner():
    if is_local_env():
        pytest.skip()

    # arrange
    lottery = deploy_lottery()
    account = get_account()

    # act
    lottery.startLottery({"from": account})
    lottery.enter({"from": account, "value": lottery.getEntranceFee() + 100000000})
    lottery.enter({"from": account, "value": lottery.getEntranceFee() + 100000000})
    fund_with_link(lottery)
    lottery.endLottery({"from": account})
    time.sleep(180)
    print("WINNER:", lottery.winner())

    # assert
    assert lottery.winner() == account
    assert lottery.balance() == 0
