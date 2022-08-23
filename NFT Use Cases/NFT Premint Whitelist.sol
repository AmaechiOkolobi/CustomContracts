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
  // Address of Business Wallet
  address private businessWallet;
  // Maximum amount of NFTs 
  uint256 public maxSupply = 100; 
  // Max amount of NFTs per User
  uint256 public maxMintAmount = 5;
  // Pause NFT Minting
  bool public paused = false;
  // Reveal NFTs
  bool public revealed = false;
  // Pinata route for unreaveled NFT Storage
  string public notRevealedUri;
  //Whitelist - address and max minting amount
  mapping (address => uint256) private _whitelist;
  //Events Redeem Store
  mapping(uint256=>uint256) public redeems;
  uint256 maxRedeems = 5; //Change Value


  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _initNotRevealedUri
  ) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
  }

  function whitelist(address addresses, uint8 maxMint) external  onlyOwner {
    _whitelist[addresses] = maxMint;
  }
  
  //Whitelist
  function whitelistBatch(address[] calldata addresses, uint8 maxMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++){
          _whitelist[addresses[i]] = maxMint;
        }
  }

  // View Base URI
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  //Redeem 
  function redeem(uint256 tokenId, address sender) external {
    sender = _msgSender();
    require(!paused);
    require(redeems[tokenId] < maxRedeems);
    uint256 ownerTokenCount = balanceOf(sender);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(sender, i);
      if (tokenIds[i] == tokenId) {
        redeems[tokenId]++;
      }
    }
  }

 function redeemLeft(uint256 tokenId) external view returns (uint256){
     return (maxRedeems - redeems[tokenId]);
 }

  // Mint NFT
  function mint(uint256 _mintAmount) external payable {
    uint256 supply = totalSupply();
    // Require user is on whitelist and has not exceeded mint amount
    require(_mintAmount <= _whitelist[_msgSender()], "Exceeded max available to purchase");
    // Require Pause = False
    require(!paused);
    // Require Mint > 1 NFT
    require(_mintAmount > 0);
    // Require Mint < Max Amount
    require(_mintAmount <= maxMintAmount);
    // Require mint amount is not greater than supply
    require(supply + _mintAmount <= maxSupply);
    // Owner can mint no fee, else must pay cost*amount
    if (_msgSender() != owner()) {
      require(msg.value >= cost * _mintAmount);
    }
    //Mint x amount of NFTs for User
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(_msgSender(), supply + i);
      _whitelist[_msgSender()]++;
    }
  }

   //Air Drop NFT to recipient address
  function air_drop(address _recipient) external onlyOwner {
        uint256 tokenId = totalSupply();
        tokenId++;
        _safeMint(_recipient, tokenId);
  }

  //Air Drop NFT to recipient address
  function air_drop(address[] calldata _recipient) external onlyOwner {
        uint256 tokenId = totalSupply();
        for (uint256 i = 0; i < _recipient.length; i++){
          tokenId++;
          _safeMint(_recipient[i], tokenId);
        } 
  }

  // Return Token IDs of Address
  function walletOfOwner(address _owner) external view returns (uint256[] memory) {
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
  function reveal() external onlyOwner {
      revealed = true;
  }
  
  //Set Cost of NFT mint
  function setCost(uint256 _newCost) external onlyOwner {
    cost = _newCost;
  }

  //Set Max Amount of NFTs minted by user
  function setmaxMintAmount(uint256 _newmaxMintAmount) external onlyOwner {
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
  function setBaseExtension(string memory _newBaseExtension) external onlyOwner {
    baseExtension = _newBaseExtension;
  }

  //Pause NFT Minting
  function pause(bool _state) external onlyOwner {
    paused = _state;
  }
 
  //Withdraw funds from contract to Owner Address
  function withdraw() external payable onlyOwner {
    //10% community address and business address
    (bool hs, ) = payable(charityWallet).call{value: address(this).balance * 5 / 100}("");
    require(hs);

    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    // =============================================================================
  }
}
