// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721URIStorage {
  //Track Token IDs
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  //marketplace address
  address contractAddress;

  //pass Market address 
  constructor(address marketAddress) ERC721("Tokens", "TOK"){
    contractAddress = marketAddress;
  }

  function createToken(string memory tokenURI) public returns (uint) {
    //Create Token IDs
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();

    _mint(msg.sender, newItemId);
    
    _setTokenURI(newItemId, tokenURI);
    setApprovalForAll(contractAddress, true);

    //Send Token ID to Market
    return newItemId;
  }
}