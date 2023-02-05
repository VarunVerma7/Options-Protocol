// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";

interface IERC20 {
    /// @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @dev Emitted when the allowance of a `spender` for an `owner` is set, where `value`
    /// is the new allowance.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Moves `amount` tokens from the caller's account to `to`.
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Returns the remaining number of tokens that `spender` is allowed
    /// to spend on behalf of `owner`
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
    /// @dev Be aware of front-running risks: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Returns the decimals places of the token.
    function decimals() external view returns (uint8);
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
        require(msg.value == 0.5 ether, "Pay up brah");

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
            scaleFactor = 1e12;
        } else if (stableCoin == usdt) {
            scaleFactor = 1e10;
        } else {
            scaleFactor = 1e1; // DAI
        }

        // send the money to the option creator, they have had to approve first
        uint256 totalCostOfExercising = option.buyPerEthPrice * option.etherOfCall / scaleFactor;
        console.log("Total cost of exercising scaled is ", totalCostOfExercising / scaleFactor);
        IERC20(stableCoin).transferFrom(msg.sender, optionSeller, totalCostOfExercising);

        // send the option to the recipient, delete all data
        console.log("Sending this ether to bob", option.etherOfCall / 1e18);
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
    function removeStableCoin(address stableCoin) external onlyOwner {}

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
