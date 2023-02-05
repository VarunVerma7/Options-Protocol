// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// call option: the right to buy an asset at a specific price

contract CallOptionsContract {
    address public owner;
    address public pendingOwner;
    address public usdc;
    address public dai;
    address public usdt;
    mapping(address => bool) public approvedTokens;
    address[] public optionSellers;
    bool internal locked;

    constructor() {
        owner = msg.sender;
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        approvedTokens[usdc] = true;
        approvedTokens[dai] = true;
        approvedTokens[usdt] = true;
    }

    struct Option {
        uint256 expiration;
        uint256 etherOfCall;
        bool purchased;
        address purchaser;
        uint256 buyPerEthPrice;
    }

    mapping(address => Option) public options;
    mapping(address => Option) public buyersOptions;
    Option[] public totalOptions;

    function sellCallOption(uint256 usdcPerEth) external payable noReentrant {
        require(optionSellers.length <= 1000, "Currently Full");
        require(msg.value >= 1 ether, "Option must be greater than 1 ether");

        uint256 expiration = block.timestamp + 30 days;

        options[msg.sender] = Option({
            expiration: expiration,
            etherOfCall: msg.value,
            purchased: false,
            purchaser: address(0x0),
            buyPerEthPrice: usdcPerEth // Giving them the right to exercise the ability to buy ETH from this option at amount per ETH
        });

        optionSellers.push(msg.sender);
    }

    function buyCallOption(address seller) external payable noReentrant {
        // retrieve option from seller and set the purchaser to the msg.sender
        Option storage option = options[seller];
        option.purchaser = msg.sender;

        // not purchased before
        require(!option.purchased);

        // not expired
        require(block.timestamp <= option.expiration, "Option cannot be expired");
        option.purchased = true;

        // send the option creator their premium:
        require(msg.value >= (option.etherOfCall * 3 / 100), "Premium is 3% of the order size");

        (bool success,) = payable(seller).call{value: msg.value}("");
        require(success);
    }

    function exerciseOption(address optionSeller, address stableCoin) external payable noReentrant {
        // payment must be in an acceptable stablecoin
        require(approvedTokens[stableCoin], "Unacceptable token");

        // must be the purchaser of the option and it shouldn't be expired
        require(options[optionSeller].purchaser == msg.sender, "You didn't buy this option");
        require(block.timestamp <= options[optionSeller].expiration, "Expired");
        Option memory option = options[optionSeller];

        // send the stable coin to the option creator
        uint256 scaleFactor;
        if (stableCoin == usdc) {
            scaleFactor = 1e12; // USDC is 6 deicmals
        } else if (stableCoin == usdt) {
            scaleFactor = 1e10; // USDT is 8 decimals
        } else {
            scaleFactor = 1e1; // DAI is 18 decimals
        }

        // send the money to the option creator, they have had to approve first
        uint256 totalCostOfExercising = option.buyPerEthPrice * option.etherOfCall / scaleFactor;
        IERC20(stableCoin).transferFrom(msg.sender, optionSeller, totalCostOfExercising);

        // send the option to the recipient, delete all data
        (bool success,) = payable(msg.sender).call{value: option.etherOfCall}("");
        delete options[optionSeller];

        require(success);
    }

    function claimUnboughtOption() external noReentrant {
        // expired +
        require(options[msg.sender].etherOfCall > 0, "No option or already claimed!");
        require(block.timestamp >= options[msg.sender].expiration, "Option hasn't expired yet");

        uint256 value = options[msg.sender].etherOfCall;
        delete options[msg.sender];
        (bool success,) = payable(msg.sender).call{value: value}("");
        require(success);
    }

    // view functions
    function getOptionSellers() public view returns (address[] memory) {
        return optionSellers;
    }

    function getOptions() public view returns (Option[] memory) {
        return totalOptions;
    }

    // Ownership and admin stuff
    function removeStableCoin(address stableCoin) external onlyOwner {
        approvedTokens[stableCoin] = false;
    }

    function addStableCoin(address stableCoin) external onlyOwner {
        approvedTokens[stableCoin] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setOwner(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    function claimOwnership() external {
        if (msg.sender == pendingOwner) {
            owner = pendingOwner;
        } else {
            revert("You're not owner");
        }
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    // fallback / receive
    fallback() external payable {}

    receive() external payable {}
}
