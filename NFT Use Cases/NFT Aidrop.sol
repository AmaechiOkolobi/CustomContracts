// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721Enumerable, Ownable {
  using Strings for uint256;

  // Pinata route for NFT Storage
  string baseURI;
  // Metadata for NFT Storage
  string public baseExtension = ".json";
  // Fee for NFT Mint
  uint256 public cost = 0.05 ether;
  // Address of Charity Wallet
  address private charityWallet;
  // Maximum amount of NFTs 
  uint256 public maxSupply = 10000;
  // Max amount of NFTs per User
  uint256 public maxMintAmount = 20;
  // Pause NFT Minting
  bool public paused = false;
  // Reveal NFTs
  bool public revealed = false;
  // Pinata route for unreaveled NFT Storage
  string public notRevealedUri;

  constructor(string memory _name, string memory _symbol, string memory _initBaseURI, string memory _initNotRevealedUri) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
  }

  // View Base URI
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // Mint NFT
  function mint(uint256 _mintAmount) public payable {
    uint256 supply = totalSupply();
    // Require Pause = False
    require(!paused);
    // Require Mint > 1 NFT
    require(_mintAmount > 0);
    // Require Mint < Max Amount
    require(_mintAmount <= maxMintAmount);
    // Require mint amount is not greater than supply
    require(supply + _mintAmount <= maxSupply);
    // Owner can mint no fee, else must pay cost*amount
    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }
    //Mint x amount of NFTs for User
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }

  //Air Drop NFT to recipient address
  function air_drop(address _recipient) public onlyOwner {
        uint256 supply = totalSupply();
        supply++;
        _safeMint(_recipient, supply);
    }

  // Return Owner Address
  function walletOfOwner(address _owner) public view returns (uint256[] memory) {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  // Returns Pinata Link for referenced NFT
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    // Require tokenId to exist, If Id does not exist return error message
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    // If NFTs not revealed return notRevealedUri, else return URI
    if(revealed == false) {
        return notRevealedUri;
    }
    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  //only owner can reveal NFTs
  function reveal() public onlyOwner {
      revealed = true;
  }
  
  //Set Cost of NFT mint
  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  //Set Max Amount of NFTs minted by user
  function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
    maxMintAmount = _newmaxMintAmount;
  }
  
  //Set URI of not revealed NFT
  function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
    notRevealedUri = _notRevealedURI;
  }

  //Set URI of NFT
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  //Set Base Extension
  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  //Pause NFT Minting
  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
 
  //Withdraw funds from contract to Owner Address
  function withdraw() public payable onlyOwner {

    (bool hs, ) = payable(charityWallet).call{value: address(this).balance * 5 / 100}("");
    require(hs);

    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    // =============================================================================
  }
}
