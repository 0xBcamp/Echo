// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EventTicket is ERC721, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;
  uint256 public maxSupply;
  string public baseURI;

  constructor(
    string memory name,
    string memory symbol,
    uint256 _maxSupply,
    string memory _uri
  ) ERC721(name, symbol) {
    maxSupply = _maxSupply;
    baseURI = _uri;
  }

  function mint(address to) public onlyOwner returns (uint256) {
    require(_tokenIdCounter.current() < maxSupply, "Maximum supply reached");
    _tokenIdCounter.increment();
    uint256 newTokenId = _tokenIdCounter.current();
    _safeMint(to, newTokenId);
    return newTokenId;
  }

  function updateBaseURI(string memory _newURI) public onlyOwner returns (string memory) {
    baseURI = _newURI;
    return baseURI;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }
}
