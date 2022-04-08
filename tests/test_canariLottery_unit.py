from brownie import CanariLottery, accounts, config, network, exceptions
from web3 import Web3
from scripts.deploy_lottery import deploy_lottery
from scripts.helpful_scripts import (
    get_account,
    get_contract,
    is_local_env,
    fund_with_link,
)
import pytest

ONE_ETH_IN_USD = 3449.92
LOTTERY_ENTRY_USD = 50


def test_get_entrance_fee():
    if not is_local_env():
        pytest.skip()

    # Arrange
    lottery = deploy_lottery()

    # act
    entrance_fee = lottery.getEntranceFee()
    expected_entrance_fee = Web3.toWei((LOTTERY_ENTRY_USD / ONE_ETH_IN_USD), "ether")

    # Assert
    print(entrance_fee, "==", expected_entrance_fee)
    assert entrance_fee == expected_entrance_fee


def test_cant_enter_unless_started():
    if not is_local_env():
        pytest.skip()

    # Arrange
    lottery = deploy_lottery()

    # act / assert
    with pytest.raises(AttributeError):
        lottery.enter({"from": get_account(), "value": lottery.getEntranceFee()})


def test_can_enter_and_start():
    if not is_local_env():
        pytest.skip()

    # Arrange
    lottery = deploy_lottery()
    account = get_account()

    # act
    lottery.startLottery({"from": account})
    lottery.enter({"from": account, "value": lottery.getEntranceFee()})

    # assert
    assert lottery.players(0) == account


def test_can_end_lottery():
    if not is_local_env():
        pytest.skip()

    # Arrange
    lottery = deploy_lottery()
    account = get_account()

    # act
    lottery.startLottery({"from": account})
    lottery.enter({"from": account, "value": lottery.getEntranceFee()})
    fund_with_link(lottery)
    lottery.endLottery({"from": account})

    # assert
    assert lottery.lotteryState() == 2


def test_can_pickup_winner_correctly():
    if not is_local_env():
        pytest.skip()
    # Arrange
    lottery = deploy_lottery()
    account = get_account()
    STATIC_RNG = 777

    # act
    lottery.startLottery({"from": account})
    lottery.enter({"from": account, "value": lottery.getEntranceFee()})
    lottery.enter({"from": get_account(index=1), "value": lottery.getEntranceFee()})
    lottery.enter({"from": get_account(index=2), "value": lottery.getEntranceFee()})
    fund_with_link(lottery)
    transaction = lottery.endLottery({"from": account})
    request_id = transaction.events["RequestedRandomness"]["requestId"]
    get_contract("vrf_coordinator").callBackWithRandomness(
        request_id, STATIC_RNG, lottery.address, {"from": account}
    )
    # 777%3 = 0
    account_starting_balance = account.balance()
    lottery_balance = lottery.balance()

    # assert
    assert lottery.winner() == account
    assert lottery.lotteryState() == 1
    assert lottery.balance() == 0
    assert account.balance() == account_starting_balance + lottery_balance
