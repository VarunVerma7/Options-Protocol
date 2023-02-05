// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// interface IERC20 {
//     function transferFrom(address sender, address receiver, uint amount) external;
// }

// // PUT option: the right to sell an asset at a specific price

// // if there is a person buying this right, they need be connected with a buyer who will buy their asset at the specified price

// contract PutOptions {

//     struct PutOption {
//         uint specifiedPrice;
//         uint expiration;
//         uint amountOfAsset;
//         uint stakedAmount;
//         address buyer;
//     }

//     mapping(address => PutOption) public putOption;

//     function tryToGetTheRightToSellAssetAtSpecifiedPrice(uint price, uint amount) external payable {
//         PutOption memory opt = PutOption(price, block.timestamp + 30 days, amount, 0, address(0x0));
//     }

//     function sellMyOptionAtPrice() external {
//         PutOption storage opt = putOption[msg.sender];

//         // send the user their money
//         IERC20(usdc).transfer(msg.sender, stakedAmount);

//         // send the staker the asset
//         payable(opt.buyer).call{value: opt.amountOfAsset}("");

//     }

//     function iWillBuyYourAssetAtPrice(address optioner) external payable {
//         PutOption storage opt = putOption[optioner];

//         opt.stakedAmount = msg.value;

//         uint stakedAmountIncaseSold = msg.value;

//     }

//     // only can happen through the commitment to buy the asset at a specified price
//     function willingToGiveAbilityToSellAssetAtSpecifiedPrice() external {

//     }
// }
