// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";
contract NftAuction is Initializable, UUPSUpgradeable {
    struct Auction {
       address seller;
       uint256 duration;
       uint256 startPrice;
       uint256 startTime;
       bool ended;
       address highestBidder;
         uint256 highestBid;
         address nftContract;
            uint256 tokenId;
            address nftAddress;

    }

    mapping(uint256 => Auction) public auctions;
    uint256 public nextAuctionId;
    address public admin;
    mapping(address => AggregatorV3Interface) public priceFeeds;
    function initialize() public initializer {
        admin = msg.sender;
    }
  
    function setPriceFeed(address token, address feed) external {
        require(msg.sender == admin, "Only admin can set price feed");
        priceFeeds[token] = AggregatorV3Interface(feed);
    }
    function getChainlinkDataLatestAnswer(address token) public view returns (int256) {
        AggregatorV3Interface priceFeed = priceFeeds[token];
        require(address(priceFeed) != address(0), "Price feed not set for this token");
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return answer;
    }
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 duration,
        uint256 startPrice,
        address nftAddress
    ) external {
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        auctions[nextAuctionId] = Auction({
            seller: msg.sender,
            duration: duration,
            startPrice: startPrice,
            startTime: block.timestamp,
            ended: false,
            highestBidder: address(0),
            highestBid: 0,
            nftContract: nftContract,
            tokenId: tokenId,
            nftAddress: nftAddress
        });
        nextAuctionId++;
    }
    function placeBid(uint256 auctionId, address bidToken, uint256 bidAmount) external {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp < auction.startTime + auction.duration, "Auction ended");
        uint256 payValue ;
        if(bidToken != address(0)){
            payValue = (bidAmount * uint256(getChainlinkDataLatestAnswer(bidToken))) / 1e8;
    }else{
        bidAmount = msg.value;
        payValue =  bidAmount * uint256(getChainlinkDataLatestAnswer(address(0)));
    }
      uint startPriceValue = auction.startPrice * uint256(getChainlinkDataLatestAnswer(auction.nftAddress));
        require(payValue >= startPriceValue, "Bid below start price");
    uint highestBidValue = auction.highestBid * uint256(getChainlinkDataLatestAnswer(auction.nftAddress));
        require(payValue > highestBidValue, "There already is a higher bid");
        if(auction.highestBid > 0){
            if(auction.nftAddress == address(0)){
                payable(auction.highestBidder).transfer(auction.highestBid);
            }else{
                IERC20(auction.nftAddress).transfer(auction.highestBidder, auction.highestBid);
            }
        }
          auction.nftAddress = bidToken;
          auction.highestBid = bidAmount;
          auction.highestBidder = msg.sender;
            }
            function endAuction(uint256 _auctionId) external{
                Auction storage auction = auctions[_auctionId];
                require(block.timestamp >= auction.startTime + auction.duration, "Auction already ended");
                require(!auction.ended, "Auction already ended");
                if(auction.highestBid > 0){
                    if(auction.nftAddress == address(0)){
                        payable(auction.seller).transfer(auction.highestBid);
                    }else{
                        IERC20(auction.nftAddress).transfer(auction.seller, auction.highestBid);
                    }
                }
                // IERC721(auction.nftContract).transferFrom(address(this), auction.highestBidder, auction.tokenId);
                // payable(address(this)).transfer(address(this).balance);
            }
              function _authorizeUpgrade(address) internal view override {
        // 只有管理员可以升级合约
        require(msg.sender == admin, "Only admin can upgrade");
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
