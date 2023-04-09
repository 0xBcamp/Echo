// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EventTicket.sol";

// This contract manages the sale of tickets for an event using an NFT contract
// It inherits the Ownable contract to ensure that only the contract owner can call certain functions
// It also implements the IERC721Receiver interface to handle incoming NFT transfers
abstract contract TicketManager is Ownable, IERC721Receiver {
  // Public variables
  uint256 public basePrice; // The base price of each ticket
  address public nftAddress; // The address of the NFT contract (tickets)
  uint256 public totalTickets; // The total number of tickets available for sale
  uint256 public ticketsSold; // The number of tickets sold so far
  uint256 public totalRevenue; // The total revenue generated from ticket sales
  uint256 public startTime; // The start time of the ticket sale
  uint256 public endTime; // The end time of the ticket sale
  uint256 public discountPercentage; // The percentage discount applied to the base price of each ticket

  // Mapping to keep track of the number of tickets owned by each buyer
  mapping(address => mapping(address => uint256)) ticketBalances;

  event TicketPurchased(address indexed buyer, uint256 price);
  event BasePriceChanged(uint256 price);

  constructor(
    string memory _eventName,
    string memory _baseURI,
    string memory _symbol,
    uint256 _basePrice,
    uint256 _totalTickets,
    uint256 _startTime,
    uint256 _endTime
  ) {
    // Initialize public variables
    basePrice = _basePrice;
    totalTickets = _totalTickets;
    startTime = _startTime;
    endTime = _endTime;

    // Create a new NFT contract for the event
    EventTicket nftContract = new EventTicket(string(abi.encodePacked(_eventName, " Ticket")), _symbol, _totalTickets, _baseURI);
    nftAddress = address(nftContract); // Set the address of the NFT contract
  }

  // Function to purchase a ticket
  function purchaseTicket() public payable {
    require(block.timestamp >= startTime, "Ticket sales have not started yet");
    require(block.timestamp <= endTime, "Ticket sales have ended");
    require(totalTickets > ticketsSold, "This event sold out!");

    uint256 price = getCurrentPrice();
    require(msg.value >= price, "Insufficient funds to purchase tickets");

    EventTicket nftContract = EventTicket(nftAddress);

    // Mint new ticket NFT and transfer ownership to the buyer
    nftContract.mint(msg.sender);

    // Update the ticket balance of the buyer
    ticketBalances[msg.sender][nftAddress]++;

    ticketsSold++;
    totalRevenue += msg.value;

    emit TicketPurchased(msg.sender, msg.value);
  }

  // Function to get the current price of a ticket based on market conditions
  function getCurrentPrice() public view returns (uint256) {
    uint256 timeLeft = endTime - block.timestamp;
    uint256 ticketsLeft = totalTickets - ticketsSold;

    // Calculate the average number of tickets sold per second
    uint256 saleRate = ticketsSold / (block.timestamp - startTime);

    // Calculate the target sale rate based on the remaining time and inventory
    uint256 targetSaleRate;
    if (ticketsLeft == 0) {
      targetSaleRate = saleRate;
    } else {
      targetSaleRate = (ticketsLeft * 2) / timeLeft; // Sell remaining tickets in half the remaining time
    }

    // Calculate the adjustment factor based on the difference between the target and actual sale rates
    uint256 adjustmentFactor;
    if (saleRate >= targetSaleRate) {
      adjustmentFactor = (saleRate - targetSaleRate) / (targetSaleRate / 100);
    } else {
      adjustmentFactor = (targetSaleRate - saleRate) / (targetSaleRate / 100);
    }

    // Apply the adjustment factor to the base price
    uint256 adjustedPrice = (basePrice * (100 + adjustmentFactor)) / 100;

    return adjustedPrice;
  }

  // updateBasePrice function allows the contract owner to update the base ticket price for the event
  function updateBasePrice(uint256 newPrice) public onlyOwner {
    basePrice = newPrice;
    emit BasePriceChanged(newPrice);
  }

  // updateTicketURI function allows the contract owner to update the base URI for
  // the NFTs that represent the event tickets.
  // The new URI is passed as an argument and is then passed on to the updateBaseURI function of the EventTicket contract
  function updateTicketURI(string memory _newURI) public onlyOwner {
    EventTicket nftContract = EventTicket(nftAddress);
    nftContract.updateBaseURI(_newURI);
  }

  // setDiscount function allows the contract owner to set a discount percentage for the ticket price
  function setDiscount(uint256 percentage) public onlyOwner {
    require(discountPercentage == 0, "Need to cancel the current discount to set a new discount rate");
    require(percentage < 100, "Discount should be less than 100%, otherwise is not a discount");
    require(percentage > 0, "Discount should be a positive number between 0 and 99");
    discountPercentage = percentage;
    basePrice = (basePrice * (100 - percentage)) / 100;
  }

  // cancelDiscount function allows the contract owner to cancel any previously set discount
  function cancelDiscount() public onlyOwner {
    require(discountPercentage > 0, "There's no discount to cancel");
    basePrice = (basePrice * 100) / (100 - discountPercentage);
    discountPercentage = 0;
  }

  // withdraw function allows the contract owner to withdraw the total revenue earned from ticket sales once the event has ended.
  function withdraw() public onlyOwner {
    require(block.timestamp > endTime, "Ticket sales still active");
    (bool sent, ) = owner().call{ value: totalRevenue }("");
    require(sent, "Failed to withdraw the revenue");
  }
}
