// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
 
contract Market is ReentrancyGuard {

  //Track NFT IDs
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;
  
  //Track Owned NFTs by Owner
  //Create NESTED MAPPING FOR EACH USER TO TRACK NFT OWNED
  mapping(uint256 => Counters.Counter) private _itemsOwned; 

  //Assign Owner and Commission for listing
  address payable owner;
  uint256 listingPrice = 0.025 ether;

  constructor() {
    owner = payable(msg.sender);
  }

  //Set NFT Listing Details
  struct NftListing {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
  }

  //Track Listed NFTs
  mapping(uint256 => NftListing) private idOfNftListing;

  //Create NFT Listing Event
  event NftListingCreate (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
  );

  //Listing Fee
  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }

  //List NFT for Sale
  function createNftListing (
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {//Prevent Re-Entry Attack
    
    //NFT Listing Price must be at least 0.1 Ether
    //Owner must pay listingPrice fee to List NFT for Sale
    require(price>0.1 ether, "Price must be at least 0.1 Ether");
    require(msg.value == listingPrice, "Price must be equal to listing price");

    _itemIds.increment();
    uint256 itemId = _itemIds.current();

    idOfNftListing[itemId] = NftListing(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price,
      false
    );

    //Transfer Ownership of NFT to Market Contract
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
   
    //Log NFT Listing
    emit NftListingCreate(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false
    ); 
  }

  //Purchase Listed NFT
  function buyNft(
    address nftContract,
    uint256 itemId
  ) public payable nonReentrant{
    //obtain price and ID of selected token
    uint price = idOfNftListing[itemId].price;
    uint tokenId = idOfNftListing[itemId].tokenId;

    //Ensure correct price has been input
    //change 0.1 etger to price testing
    require(msg.value >= 0.1 ether, "Please submit the listed price in order to complete purchase");

    //Process Payment and Transfer Ownership
    idOfNftListing[itemId].seller.transfer(msg.value);
    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    idOfNftListing[itemId].owner = payable(msg.sender);
    idOfNftListing[itemId].sold = true;
    payable(owner).transfer(listingPrice);
  }

  //View NFTs on the Market
  function viewNftListings() public view returns (NftListing[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    //Track Unsold NFTs
    NftListing[] memory items = new NftListing[](unsoldItemCount);
    for (uint i=0; i<itemCount; i++) {
      //Identifies NFT wth Owner value of Contract Address
      if (idOfNftListing[i+1].owner == address(0)){
        uint currentId = idOfNftListing[i+1].itemId;

        //Use Mapping to Identify Unsold NFTs
        NftListing storage currentItem = idOfNftListing[currentId];
        items[currentIndex] = currentItem;
        currentIndex+=1;
      }
    }
    return items;
  }

  //View NFts owned by function caller 
  function viewMyNfts() public view returns (NftListing[] memory) {
    uint totalNfts = _itemIds.current();
    uint nftCount = 0;
    uint currentIndex = 0;

    //Track NFTs owned by caller
    for (uint i = 0; i<totalNfts; i++) {
      if(idOfNftListing[i+1].owner == msg.sender) {
        nftCount +=1;
      }
    }

    //Pass all NFTs owned by caller to array idOfNftListing
    NftListing[] memory items = new NftListing[](nftCount);
    for (uint i=0; i<totalNfts; i++) {
      if(idOfNftListing[i+1].owner == msg.sender) {
        uint currentId = idOfNftListing[i+1].itemId;
        NftListing storage currentNft = idOfNftListing[currentId];
        items[currentIndex] = currentNft;
        currentIndex+=1;
      }
    }
    return items;
  }

  //View NFTs listed by function caller
  function viewListedNfts() public view returns (NftListing[] memory) {
    uint totalNfts = _itemIds.current();
    uint nftCount = 0;
    uint currentIndex = 0;

    //Track items listed by caller
    for (uint i = 0; i<totalNfts; i++) {
      if(idOfNftListing[i+1].seller == msg.sender) {
        nftCount +=1;
      }
    }

    //Pass all NFTs listed by caller to array idOfNftListing
    NftListing[] memory items = new NftListing[](nftCount);
    for (uint i=0; i<totalNfts; i++) {
      if(idOfNftListing[i+1].seller == msg.sender) {
        uint currentId = idOfNftListing[i+1].itemId;
        NftListing storage currentNft = idOfNftListing[currentId];
        items[currentIndex] = currentNft;
        currentIndex+=1;
      }
    }
    return items;
  }
}