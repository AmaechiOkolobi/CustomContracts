// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IToken.sol";

contract Factory is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private counter;
    Token token;

    /* State Variables */
    NFT[] public collections;
    mapping(address => uint256) private collectionsOfUser;
    mapping(uint256 => address) private collectionIdToUser;
    mapping(address => Collection) private Collections;

    struct Collection{
        uint256 collectionId;
        string collectionName;
        uint256 collectionSupply;
    }
        
    event CollectionCreated(address indexed owner, string indexed _name, address indexed collectionAddress);

    constructor() {}

    /* Collection Functions */

    function createCollection(
        string memory _name,
        string memory _symbol,
        bool openMarketTradeable,
        uint256 _mintCost, 
        uint256 _supply,
        uint256 _maxMintAmount
    ) external {
        uint256 current = counter.current();
        counter.increment();

        NFT newCollection = new NFT(
            msg.sender,
            _name,
            _symbol,
            openMarketTradeable,
            _mintCost, 
            _supply,
            _maxMintAmount
        );

        WonderCollections[address(newCollection)] = WonderCollection(
            counter.current(),
            _name,
            _supply
        );

        collections.push(newCollection);
        collectionsOfUser[msg.sender]++;
        collectionIdToUser[current] = msg.sender;

        emit CollectionCreated(msg.sender, _name, address(newCollection));
    }

    /* View/Pure Functions */

    function viewCollections() external view returns (NFT[] memory ){
        return collections;
    }

    function viewCollectionsOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 collectionCount = collectionsOfUser[_owner];
        uint256[] memory collectionIds = new uint256[](collectionCount);
        for (uint256 i; i < collectionCount; i++) {
            if(collectionIdToUser[i] == _owner){
                collectionIds[i] = i;
            }
        }
        return collectionIds;
    }

    /* Withdraw Funds*/
    function withdraw() public payable onlyOwner {

    (bool hs, ) = payable(owner()).call{value: address(this).balance * 5 / 100}("");
    require(hs);

    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    // =============================================================================
  }
}