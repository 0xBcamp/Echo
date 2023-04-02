// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EventTicket.sol";

abstract contract TicketManager is Ownable, IERC721Receiver {
  uint256 public basePrice;
  address public nftAddress;
  uint256 public totalTickets;
  uint256 public ticketsSold;
  uint256 public totalRevenue;
  uint256 public startTime;
  uint256 public endTime;
  uint256 public discountPercentage;

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
    basePrice = _basePrice;
    totalTickets = _totalTickets;
    startTime = _startTime;
    endTime = _endTime;

    EventTicket nftContract = new EventTicket(string(abi.encodePacked(_eventName, " Ticket")), _symbol, _totalTickets, _baseURI);

    nftAddress = address(nftContract);
  }

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

  function updateBasePrice(uint256 newPrice) public onlyOwner {
    basePrice = newPrice;
    emit BasePriceChanged(newPrice);
  }

  function updateTicketURI(string memory _newURI) public onlyOwner {
    EventTicket nftContract = EventTicket(nftAddress);
    nftContract.updateBaseURI(_newURI);
  }

  function setDiscount(uint256 percentage) public onlyOwner {
    require(discountPercentage == 0, "Need to cancel the current discount to set a new discount rate");
    require(percentage < 100, "Discount should be less than 100%, otherwise is not a discount");
    discountPercentage = percentage;
    basePrice = (basePrice * (100 - percentage)) / 100;
  }

  function cancelDiscount() public onlyOwner {
    basePrice = (basePrice * 100) / (100 - discountPercentage);
    discountPercentage = 0;
  }

  function withdraw() public onlyOwner {
    // TODO should allow to withdraw anytime or only when the
    // ticketing time ends ??
    (bool sent, ) = owner().call{ value: totalRevenue }("");
    require(sent, "Failed to withdraw the revenue");
    // TODO delete contract after withdraw and time ends ??
  }
}
