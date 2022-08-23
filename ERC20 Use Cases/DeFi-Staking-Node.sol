pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IJoeRouter02.sol";
import "./RewardsPool.sol";
import "hardhat/console.sol";

contract PeachNode is ERC1155, Ownable{
    using SafeMath for uint256;

    address peachToken;
    RewardsPool rewardsPool;
    address teamWallet;
    address treasury;

    address WAVAX_ADDRESS = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address JOE_ROUTER_ADDRESS = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;

    uint256 private _decimals = 10**18;
    uint256 public priceStandard = 20 * _decimals;
    uint256 public priceSlotmachine = 20 * _decimals;
    IJoeRouter02 private router = IJoeRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    uint256 constant MAX_INT = 2**256 - 1;

    // uint64 public reward = 1157;
    uint128 public time = 86400;
    
    struct Nodes {
        uint16 tier1;
        uint16 tier2;
        uint16 tier3;
        uint16 tier4;
        uint16 tier5;
        uint16 tier6;
    }

    Nodes public _rewards = Nodes({
        tier1: 1000,
        tier2: 400,
        tier3: 300,
        tier4: 250,
        tier5: 200,
        tier6: 75
    });

    Nodes public _limit = Nodes({
        tier1: 450,
        tier2: 2500,
        tier3: 5000,
        tier4: 10000,
        tier5: 20000,
        tier6: 0
    });

    struct Games {
        uint256 id;
        uint256 lastClaim;
    }

    constructor(
        address _peachToken,
        address _rewardsPool,
        address _teamWallet,
        address _treasury
    ) ERC1155("") {
        peachToken = _peachToken;
        rewardsPool = RewardsPool(_rewardsPool);
        teamWallet = _teamWallet;
        treasury = _treasury;
    } 

    receive() external payable {}

    // Number of Nodes Created By Tier
    mapping(uint256 => uint256) private _nodes;
    // Node Of User
    mapping(address => mapping(uint256 => Games[])) private _nodesOfOwner;
    // Price Of Node per User
    mapping(address => uint256) private _prices;

    // Number of Nodes Created
    uint256 public nodeCount;

    function getTokenBalance() public view returns(uint256){
        return IERC20(peachToken).balanceOf(_msgSender());
    }

    function approveContract() public {
        // IERC20(peachToken).approve(sender,tokenAmount);
        IERC20(peachToken).approve(address(this),MAX_INT);
    }

    function createNode(uint256 _tier, uint256 amount) 
    external
    {
        address sender = _msgSender();
        require(sender != address(0), "Invalid Address");
        require(_tier >= 1 && _tier <7, "Invalid Tier");
        require(
            isNodeAvailable(_tier, amount),"Node not available"
        );
        require(amount < 21, "Max Nodes Per Transaction Exceeded");

        if(_nodes[_tier] == 6) {
            setSlotPrice();
        }  else {
            setStandardPrice();
        }
        
        uint256 tokenAmount = _prices[sender] * amount;

        require(
            IERC20(peachToken).balanceOf(sender) >= tokenAmount, "Insufficient $PEACH Balance"
        );

        require(finaliseTransfer(sender, tokenAmount));

        for (uint256 i = 0; i < amount; i++) {
            _nodesOfOwner[sender][_tier].push(
                Games({
                    id: _tier,
                    lastClaim: block.timestamp
                })
            );
        }

        _mint(sender, _tier, amount, "");
        _nodes[_tier]+=amount;
        nodeCount+=amount;
    }

    //Distribute Tokens From Node Creation
    function finaliseTransfer(address sender, uint tokenAmount) 
    internal 
    returns(bool)
    {
        IERC20(peachToken).transferFrom(
            sender,
            address(this), 
            tokenAmount
        );

        uint256 amountToTreasury = (tokenAmount * 20) / 100;
        uint256 amountToTeam = (tokenAmount * 5) / 100;
        uint256 amountToLiquidity = ((tokenAmount * 15) / 100);
        uint256 swapAmount = amountToLiquidity/2;

        IERC20(peachToken).approve(address(JOE_ROUTER_ADDRESS), MAX_INT);
        IERC20(peachToken).approve(address(this), MAX_INT);

        IERC20(peachToken).transferFrom(
            address(this),
            treasury,
            amountToTreasury
        );

        IERC20(peachToken).transferFrom(
            address(this),
            teamWallet,
            amountToTeam
        );

        address[] memory path = new address[](2);
        path[0] = peachToken;
        path[1] = WAVAX_ADDRESS;

        router.swapExactTokensForAVAX(
            swapAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountAVAX = address(this).balance;
        router.addLiquidityAVAX{value: amountAVAX}(
            peachToken,
            amountToLiquidity,
            1,
            1,
            address(this),
            block.timestamp
        );

        uint256 amountToRewardsPool = IERC20(peachToken).balanceOf(address(this));
        IERC20(peachToken).transferFrom(
            address(this),
            address(rewardsPool),
            amountToRewardsPool
        );
        return true;
    }

    //Claim rewards
    function claimRewards(uint256 _tier)
    external
    {
        address sender = _msgSender();
        uint256 rewards = getRewards(sender, _tier);
        require(rewards > 1, "You Don't Have Enough Rewards");
        
        uint256 rewardsToPool = (rewards * 12) / 100;
        uint256 rewardsTeam = (rewards * 3) / 100;
        uint256 rewardsUser = rewards - rewardsToPool - rewardsTeam;

        IERC20(peachToken).transferFrom(
            address(rewardsPool),
            sender,
            rewardsUser
        );
        
        IERC20(peachToken).transferFrom(
            address(rewardsPool),
            teamWallet,
            rewardsTeam
        );
    }

    function compoundRewards(uint256 _tier)
    external
    {
        address sender = _msgSender();
        uint256 rewards = getRewards(sender, _tier);

        if(_nodes[_tier] == 6) {
            setSlotPrice();
        }  else {
            setStandardPrice();
        }

        require(rewards >= _prices[sender], "You Don't Have Enough Rewards");

        _nodesOfOwner[sender][_tier].push(
            Games({
                id: _tier,
                lastClaim: block.timestamp
            })
        );

        _mint(sender, _tier, 1, "");
        _nodes[_tier]++;
        nodeCount++;

    }

    // Calculate Rewards in Tier
    function getRewards(address _sender, uint256 _tier)
    internal
    returns(uint256)
    {
        require(_tier >= 1 && _tier <7, "Invalid Tier");
        uint256 multiplier;

        if(_tier ==1){
            multiplier = _rewards.tier1;
        }else if(_tier ==2){
            multiplier = _rewards.tier2;
        }else if(_tier ==3){
            multiplier = _rewards.tier3;
        }else if(_tier ==4){
            multiplier = _rewards.tier4;
        }else if(_tier ==5){
            multiplier = _rewards.tier5;
        }else if(_tier ==6){
            multiplier = _rewards.tier6;
        }

        address sender = _sender;

        Games[] storage nodes = _nodesOfOwner[sender][_tier];
        uint256 nodesCount = nodes.length;
        require(nodesCount > 0, "No available nodes");

        Games storage _game;
        uint256 rewards = 0;

        for (uint256 i = 0; i < nodesCount; i++) {
            _game = nodes[i];
            uint claimDays = ((block.timestamp - _game.lastClaim)/time);
            rewards += (claimDays*_decimals*multiplier)/1000;
            _game.lastClaim = block.timestamp;
        }

        return rewards;
    }

    function isNodeAvailable(uint256 _id, uint256 amount)
    private
    view
    returns (bool)
    {
        require(_id >= 1 && _id <7);

        if (_nodes[_id] == 1) {
            if (_nodes[_id] + amount > _limit.tier1) return false;
        }else if (_nodes[_id] == 2) {
            if (_nodes[_id] + amount > _limit.tier2) return false;
        }else if (_nodes[_id] == 3) {
            if (_nodes[_id] + amount > _limit.tier3) return false;
        }else if (_nodes[_id] == 4) {
            if (_nodes[_id] + amount > _limit.tier4) return false;
        }else if (_nodes[_id] == 5) {
            if (_nodes[_id] + amount > _limit.tier5) return false;
        }else if (_nodes[_id] == 6) {
            return true;
        }

        return true;
    }

    //Handle Upgrade Price for Games
    function setStandardPrice() 
    public 
    {
        address owner = _msgSender();
        uint256 count = 
            balanceOf(owner,1)
            +balanceOf(owner,2)
            +balanceOf(owner,3)
            +balanceOf(owner,4)
            +balanceOf(owner,5);

        if (count < 10){
            _prices[owner] = priceStandard;
        }else if (count >=10 && count < 20){
            _prices[owner] = 25* _decimals;
        } else if (count >=20 && count < 40){
            _prices[owner] = 30* _decimals;
        }else if (count >=40 && count < 80){
            _prices[owner] = 35* _decimals;
        }else if (count >=80 && count < 100){
            _prices[owner] = 40* _decimals;
        }else if (count >=100){
            _prices[owner] = 45* _decimals;
        }
    }

    //Handle Upgrade Price For Slot Machine
    function setSlotPrice() 
    public 
    {
        address owner = _msgSender();
        uint256 count = balanceOf(owner,6);

        if (count < 10){
            _prices[owner] = priceSlotmachine;
        }else if (count >=10 && count < 20){
            _prices[owner] = 25* _decimals;
        } else if (count >=20 && count < 40){
            _prices[owner] = 30* _decimals;
        }else if (count >=40 && count < 80){
            _prices[owner] = 35* _decimals;
        }else if (count >=80 && count < 100){
            _prices[owner] = 40* _decimals;
        }else if (count >=100){
            _prices[owner] = 45* _decimals;
        }
    }
}