// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Import the AggregatorV3Interface contract from the Chainlink library
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// Import the PriceConverter library
import {PriceConverter} from "./PriceConverter.sol";

// Custom error for when a non-owner tries to execute an owner-only function
error NotOwner();

contract FundMe {
    // Use the PriceConverter library for uint256 type
    using PriceConverter for uint256;

    // Mapping to store the amount funded by each address
    mapping(address => uint256) public addressToAmountFunded;
    // Array to store the addresses of funders
    address[] public funders;
    // Immutable variable to store the address of the contract owner
    address public immutable i_owner;
    // Constant for the minimum USD value required for funding (5 USD)
    uint256 public constant MINIMUM_USD = 5 * 10 ** 18;

    // Modifier to restrict access to the withdraw function to only the contract owner
    modifier onlyOwner {
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    // Constructor to set the contract owner
    constructor() {
        i_owner = msg.sender;
    }

    // Function to fund the contract
    function fund() public payable {
        require(msg.value.getConversionRate() >= MINIMUM_USD, "You need to spend more ETH!");
        // Update the amount funded by the sender
        addressToAmountFunded[msg.sender] += msg.value;
        // Add the sender's address to the funders array
        funders.push(msg.sender);
    }

    // Function to get the version of the Chainlink price feed contract
    function getVersion() public view returns (uint256) {
        // Create an instance of the AggregatorV3Interface contract
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        return priceFeed.version();
    }

    // Function to withdraw the funds, accessible only by the contract owner
    function withdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            // Get the address of the current funder
            address funder = funders[funderIndex];
            // Reset the amount funded by the current funder
            addressToAmountFunded[funder] = 0;
        }
        // Reset the funders array
        funders = new address[](0);
        // Transfer the entire contract balance to the contract owner
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    //! Explainer from: https://solidity-by-example.org/fallback/
    //* Ether is sent to contract
    //?     is msg.data empty?
    //            /   \ 
    //         yes    no
    //         /       \
    //     receive()?  fallback() 
    //      /   \ 
    //    yes    no
    //   /        \
    // receive()  fallback()

    // Fallback function to call the fund function if Ether is sent to the contract
    fallback() external payable {
        fund();
    }

    // Receive function to call the fund function if Ether is sent to the contract
    receive() external payable {
        fund();
    }
}