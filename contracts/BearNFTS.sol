// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

struct Reward {
    uint256 tokenId;
    bool claimed;
}

struct RewardClaimer {
    address addr;
    uint64 startTimestamp;
}

contract BearNFTS is Ownable, ERC721A {
    uint256 public constant TOTAL_SUPPLY = 10000;
    uint256 public constant BATCH_MINT_SIZE = 20;

    // // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
    @dev tokenId to resting start time (0 = not resting).
     */
    mapping(uint256 => uint256) private restingStarted;

    bool public restBears = false;

    /**
    @dev Cumulative per-token resting, excluding the current period.
     */
    mapping(uint256 => uint256) private restingTotal;

    // Mapping of tokenId with address to prevent duplicate assigning
    mapping(uint256 => RewardClaimer) private _rewardClaimer;

    // Mapping from owner to list of reward token IDs
    mapping(address => mapping(uint256 => Reward)) private _rewardTokens;

    // mapping owner address with reward count
    mapping(address => uint256) private _rewards;

    constructor()
        ERC721A("BearNFTS", "BearNFTS", BATCH_MINT_SIZE, TOTAL_SUPPLY)
    {}

    function addRewards(uint256[] memory tokenIds, address[] memory accounts)
        external
        onlyOwner
    {
        for (uint256 index = 0; index < tokenIds.length; index++) {
            require(!_rewardExits(tokenIds[index]), "Token Already Rewarded");
            require(
                tokenIds[index] != 0 && tokenIds[index] <= TOTAL_SUPPLY,
                "Invalid Token Id"
            );
            _rewardClaimer[tokenIds[index]] = RewardClaimer(
                accounts[index],
                uint64(block.timestamp)
            );
            uint256 length = rewardOf(accounts[index]);

            _rewardTokens[accounts[index]][length].tokenId = tokenIds[index];
            _rewards[accounts[index]]++;
        }
    }

    function tokenOfRewardByIndex(address owner, uint256 index)
        public
        view
        returns (Reward memory)
    {
        require(index < rewardOf(owner), "owner index out of bounds");
        return _rewardTokens[owner][index];
    }

    function rewardOf(address owner) public view returns (uint256) {
        require(
            owner != address(0),
            "BearNFTS: address zero is not a valid owner"
        );
        return _rewards[owner];
    }

    function claimRewards(uint256[] memory rewardIndexes) external {
        uint256 rewardBalance = rewardOf(msg.sender);
        uint256[] memory tokenIds = new uint256[](rewardIndexes.length);
        for (uint256 index = 0; index < rewardIndexes.length; index++) {
            {
                require(
                    !_rewardTokens[msg.sender][rewardIndexes[index]].claimed,
                    "Already Claimed Reward"
                );
                require(rewardIndexes[index] < rewardBalance, "Invalid index");
                tokenIds[index] = _rewardTokens[msg.sender][
                    rewardIndexes[index]
                ].tokenId;
                _rewardTokens[msg.sender][rewardIndexes[index]].claimed = true;
            }
        }
        _safeMint(msg.sender, tokenIds);
    }

    function _rewardExits(uint256 tokenId) internal view returns (bool) {
        return _rewardClaimer[tokenId].addr != address(0);
    }

    function changeRestBears(bool status) public onlyOwner {
        restBears = status;
    }

    /**
    @dev Block transfers while resting.
     */
    function _beforeTokenTransfers(
        address,
        address,
        uint256 startTokenId,
        uint256 quantity
    ) internal view override {
        uint256 tokenId = startTokenId;
        for (uint256 end = tokenId + quantity; tokenId < end; ++tokenId) {
            require(restingStarted[tokenId] == 0, "Bear: resting");
        }
    }

    function restingPeriod(uint256 tokenId)
        external
        view
        returns (
            bool resting,
            uint256 current,
            uint256 total
        )
    {
        uint256 start = restingStarted[tokenId];
        if (start != 0) {
            resting = true;
            current = block.timestamp - start;
        }
        total = current + restingTotal[tokenId];
    }

    function toggleResting(uint256 tokenId) internal {
        require(
            ownershipOf(tokenId).addr == _msgSender(),
            "ERC721ACommon: Not owner"
        );
        uint256 start = restingStarted[tokenId];
        if (start == 0) {
            require(restBears, "Bear: resting closed");
            restingStarted[tokenId] = block.timestamp;
        } else {
            restingTotal[tokenId] += block.timestamp - start;
            restingStarted[tokenId] = 0;
        }
    }

    function toggleResting(uint256[] calldata tokenIds) external {
        uint256 n = tokenIds.length;
        for (uint256 i = 0; i < n; ++i) {
            toggleResting(tokenIds[i]);
        }
    }
}
