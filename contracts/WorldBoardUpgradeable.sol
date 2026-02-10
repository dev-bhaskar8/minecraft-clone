// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title WorldBoardUpgradeable
 * @notice Featured slot board for Clawcraft worlds. Users claim a slot by paying an ERC20.
 *         90% of the claim price is paid to the previous slot holder, and 10% is rebated to the new claimer.
 *         If the slot was empty (no previous holder), the 90% stays in this contract (no treasury required).
 *
 *         The "world" is stored as a share code (compressed seed+edits string).
 */
contract WorldBoardUpgradeable is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    struct Slot {
        address holder;
        uint40 updatedAt;
        string worldCode; // base64url deflate blob produced by Clawcraft
    }

    IERC20 public paymentToken;
    uint256 public claimPrice;
    uint256 public slotCount;
    uint256 public constant PREV_HOLDER_BPS = 9000; // 90%
    uint256 public constant NEW_CLAIMER_REBATE_BPS = 1000; // 10%
    uint256 public constant MIN_OUTBID_INCREASE_BPS = 1000; // +10% minimum over previous price
    uint256 public constant BPS = 10000;

    mapping(uint256 => Slot) private _slots;
    // Last paid amount per slot. Zero means unclaimed.
    mapping(uint256 => uint256) private _lastPaid;

    event SlotClaimed(
        uint256 indexed slotId,
        address indexed newHolder,
        address indexed prevHolder,
        uint256 price,
        uint256 prevPayout,
        uint256 newClaimerRebate,
        string worldCode
    );

    event ConfigUpdated(address token, uint256 claimPrice, uint256 slotCount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);

    error InvalidSlot();
    error InvalidToken();
    error InvalidWorldCode();
    error InvalidWithdraw();
    error InsufficientBid(uint256 minRequired, uint256 bid);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address token_,
        uint256 slotCount_,
        uint256 claimPrice_
    ) public initializer {
        if (token_ == address(0)) revert InvalidToken();
        if (slotCount_ == 0 || slotCount_ > 500) revert InvalidSlot();

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        paymentToken = IERC20(token_);
        claimPrice = claimPrice_;
        slotCount = slotCount_;

        emit ConfigUpdated(token_, claimPrice_, slotCount_);
    }

    function setClaimPrice(uint256 claimPrice_) external onlyOwner {
        claimPrice = claimPrice_;
        emit ConfigUpdated(address(paymentToken), claimPrice_, slotCount);
    }

    function setSlotCount(uint256 slotCount_) external onlyOwner {
        if (slotCount_ == 0 || slotCount_ > 500) revert InvalidSlot();
        slotCount = slotCount_;
        emit ConfigUpdated(address(paymentToken), claimPrice, slotCount_);
    }

    function getSlot(uint256 slotId) external view returns (Slot memory) {
        if (slotId >= slotCount) revert InvalidSlot();
        return _slots[slotId];
    }

    function lastClaimPrice(uint256 slotId) external view returns (uint256) {
        if (slotId >= slotCount) revert InvalidSlot();
        return _lastPaid[slotId];
    }

    function minClaimPrice(uint256 slotId) public view returns (uint256) {
        if (slotId >= slotCount) revert InvalidSlot();
        uint256 last = _lastPaid[slotId];
        if (last == 0) return claimPrice;

        // ceil(last * 10%): ensures strictly > last even for tiny values.
        uint256 inc = (last * MIN_OUTBID_INCREASE_BPS + (BPS - 1)) / BPS;
        return last + inc;
    }

    /**
     * @notice Batch read slots to reduce RPC round-trips.
     * @dev Safe for UIs; do not use for on-chain consumption (large arrays).
     */
    function getSlots(uint256 start, uint256 count) external view returns (Slot[] memory slots) {
        if (count == 0) return new Slot[](0);
        if (start >= slotCount) revert InvalidSlot();

        uint256 end = start + count;
        if (end > slotCount) end = slotCount;

        uint256 n = end - start;
        slots = new Slot[](n);
        for (uint256 i = 0; i < n; i++) {
            slots[i] = _slots[start + i];
        }
    }

    /**
     * @notice Claim using the minimum required price (claimPrice for empty slots, otherwise last+10%).
     */
    function claim(uint256 slotId, string calldata worldCode) external nonReentrant {
        _claim(slotId, worldCode, minClaimPrice(slotId));
    }

    /**
     * @notice Claim with an explicit bid amount. Must be >= minClaimPrice(slotId).
     */
    function claim(uint256 slotId, string calldata worldCode, uint256 bidAmount) external nonReentrant {
        _claim(slotId, worldCode, bidAmount);
    }

    function getSlotsWithPrices(
        uint256 start,
        uint256 count
    )
        external
        view
        returns (Slot[] memory slots, uint256[] memory lastPrices, uint256[] memory minPrices)
    {
        if (count == 0) return (new Slot[](0), new uint256[](0), new uint256[](0));
        if (start >= slotCount) revert InvalidSlot();

        uint256 end = start + count;
        if (end > slotCount) end = slotCount;

        uint256 n = end - start;
        slots = new Slot[](n);
        lastPrices = new uint256[](n);
        minPrices = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            uint256 slotId = start + i;
            slots[i] = _slots[slotId];
            uint256 last = _lastPaid[slotId];
            lastPrices[i] = last;
            minPrices[i] = last == 0 ? claimPrice : (last + (last * MIN_OUTBID_INCREASE_BPS + (BPS - 1)) / BPS);
        }
    }

    function _claim(uint256 slotId, string calldata worldCode, uint256 bidAmount) internal {
        if (slotId >= slotCount) revert InvalidSlot();
        // Keep on-chain strings bounded (prevents griefing with huge calldata/storage).
        if (bytes(worldCode).length == 0 || bytes(worldCode).length > 8192) revert InvalidWorldCode();
        uint256 minReq = minClaimPrice(slotId);
        if (bidAmount < minReq) revert InsufficientBid(minReq, bidAmount);

        Slot storage s = _slots[slotId];
        address prev = s.holder;

        uint256 price = bidAmount;
        // Pull payment in.
        // NOTE: token must be a well-behaved ERC20 (CRAFT). No fee-on-transfer support.
        require(paymentToken.transferFrom(msg.sender, address(this), price), "transferFrom failed");

        uint256 rebate = (price * NEW_CLAIMER_REBATE_BPS) / BPS;
        uint256 prevPayout = price - rebate; // 90% at 10% rebate

        // Always rebate the new claimer (acts like "reward for outbidding").
        if (rebate != 0) {
            require(paymentToken.transfer(msg.sender, rebate), "rebate transfer failed");
        }

        // Pay the rest to previous holder. If slot was empty, keep funds in-contract.
        if (prev != address(0) && prevPayout != 0) {
            require(paymentToken.transfer(prev, prevPayout), "prev payout transfer failed");
        }

        s.holder = msg.sender;
        s.updatedAt = uint40(block.timestamp);
        s.worldCode = worldCode;
        _lastPaid[slotId] = price;

        emit SlotClaimed(slotId, msg.sender, prev, price, prevPayout, rebate, worldCode);
    }

    /**
     * @notice Owner can withdraw tokens locked in the contract (e.g. 90% from claims of empty slots).
     */
    function withdrawToken(address token_, address to, uint256 amount) external onlyOwner nonReentrant {
        if (token_ == address(0) || to == address(0) || amount == 0) revert InvalidWithdraw();
        require(IERC20(token_).transfer(to, amount), "withdraw transfer failed");
        emit Withdrawn(token_, to, amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
