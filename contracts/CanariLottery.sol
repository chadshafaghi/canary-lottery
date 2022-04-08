// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

//import "@chainlink/contracts/src/v0.8/vendor/SafeMathChainlink.sol";

contract CanariLottery is Ownable, VRFConsumerBase {
    //  using SafeMathChainlink for uint256;
    address payable[] public players;
    address payable public winner;
    uint256 public usdEntryFee;
    AggregatorV3Interface internal ethUsdPriceFeed;

    enum LOTTERY_STATE {
        OPEN,
        CLOSE,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lotteryState;

    // RandomNumber VRFConsumerBase params
    bytes32 internal vrfKeyHash;
    uint256 public vrfLinkFee;
    uint256 public randomness;

    event RequestedRandomness(bytes32 requestId);

    // calling the VRFConsumerBase constructor within ther Smart Contract CanaryLottery constructor
    constructor(
        address _priceFeedAddress,
        address _vrfCoordinatorAdr,
        address _vrfLinkTokenAdr,
        bytes32 _vrfKeyHash,
        uint256 _vrfFee
    ) public VRFConsumerBase(_vrfCoordinatorAdr, _vrfLinkTokenAdr) {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lotteryState = LOTTERY_STATE.CLOSE;
        vrfKeyHash = _vrfKeyHash;
        vrfLinkFee = _vrfFee;
    }

    function enter() public payable {
        require(
            lotteryState == LOTTERY_STATE.OPEN,
            "The Canari Loterry is not yet open"
        );
        require(
            msg.value >= getEntranceFee(),
            "You haven't sent enought ETH. You need at least 50$."
        );
        // 50 USD min to participate
        players.push(payable(msg.sender));
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10; //18 decimals
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lotteryState != LOTTERY_STATE.OPEN,
            "The Lottery is already open"
        );
        lotteryState = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {
        // TODO: INSTANTIATE A NEW LINKTOKEN INTERFACE TO COMPLETE THE REQUIRE STATEMENT
        // require(
        //     (linkTokenInterface.balanceOf(address(this))) > vrfLinkFee,
        //     "Not enough LINK - fill contract with faucet"
        // );
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(vrfKeyHash, vrfLinkFee);
        emit RequestedRandomness(requestId);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lotteryState == LOTTERY_STATE.CALCULATING_WINNER,
            "You can't request a random number as the Lottery is not in the correct state"
        );
        require(_randomness > 0, "Random number must be greater than 0");
        uint256 indexOfWinner = _randomness % players.length;
        winner = players[indexOfWinner];
        winner.transfer(address(this).balance);

        // Resetting the Lottery
        players = new address payable[](0);
        lotteryState = LOTTERY_STATE.CLOSE;
        randomness = _randomness;
    }
}
