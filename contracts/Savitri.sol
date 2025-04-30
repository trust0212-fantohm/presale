// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Savitri is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    struct SalePhase {
        uint256 tokenLimit;
        uint256 pricePerToken; // in USDT with 6 decimals (e.g., $0.35 = 350000)
    }

    SalePhase[] public phases;
    uint256 public currentPhase;
    uint256 public tokensSold;
    mapping(address => uint256) public userPurchases;

    ERC20Upgradeable public usdt;
    address public treasury;

    uint256 public constant minPurchaseAmount = 50 * 10 ** 6;
    uint256 public constant maxPurchaseAmount = 1_000_000 * 10 ** 6;
    uint256 public constant DECIMALS = 1e6;
    uint256 public constant MAX_SUPPLY = 240_000_000 * DECIMALS;

    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount);
    event PhaseAdvanced(uint256 newPhase);
    event EmergencyWithdraw(address token, uint256 amount);

    function initialize(address _usdt, address _treasury) public initializer {
        __ERC20_init("Savitri", "SAVI");
        __Ownable_init(msg.sender);
        __Pausable_init();

        usdt = ERC20Upgradeable(_usdt);
        treasury = _treasury;

        // Setup phases
        phases.push(SalePhase(35_000_000 * DECIMALS, 350000));
        phases.push(SalePhase(42_500_000 * DECIMALS, 400000));
        phases.push(SalePhase(21_250_000 * DECIMALS, 450000));
        phases.push(SalePhase(21_250_000 * DECIMALS, 500000));
        phases.push(SalePhase(60_000_000 * DECIMALS, 550000));
        phases.push(SalePhase(60_000_000 * DECIMALS, 600000));
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function buy(uint256 usdtAmount) external whenNotPaused {
        require(usdtAmount >= minPurchaseAmount, "Amount below minimum");
        require(userPurchases[msg.sender] + usdtAmount <= maxPurchaseAmount, "Exceeds max purchase limit");
        require(currentPhase < phases.length, "Sale completed");

        uint256 remainingUSDT = usdtAmount;
        uint256 totalUSDTSpent = 0;
        uint256 tokensToBuy = 0;
        uint256 phaseIndex = currentPhase;

        while (remainingUSDT > 0 && phaseIndex < phases.length) {
            SalePhase memory phase = phases[phaseIndex];
            uint256 tokensLeft = phase.tokenLimit - getTokensSoldInPhase(phaseIndex);

            if (tokensLeft == 0) {
                phaseIndex++;
                continue;
            }

            uint256 tokensAtPrice = (remainingUSDT * DECIMALS) / phase.pricePerToken;
            uint256 buyingNow = tokensAtPrice > tokensLeft ? tokensLeft : tokensAtPrice;
            uint256 costForTokens = (buyingNow * phase.pricePerToken) / DECIMALS;

            if (buyingNow == 0 || costForTokens > remainingUSDT) break;

            tokensToBuy += buyingNow;
            remainingUSDT -= costForTokens;
            totalUSDTSpent += costForTokens;

            phaseIndex++;
        }

        require(tokensToBuy > 0, "Insufficient USDT to buy any tokens");
        require(totalSupply() + tokensToBuy <= MAX_SUPPLY, "Exceeds max supply");

        tokensSold += tokensToBuy;
        userPurchases[msg.sender] += totalUSDTSpent;

        if (tokensSold >= getPhaseEnd(currentPhase)) {
            currentPhase++;
            emit PhaseAdvanced(currentPhase);
        }

        require(usdt.transferFrom(msg.sender, treasury, totalUSDTSpent), "USDT transfer failed");
        _mint(msg.sender, tokensToBuy);
        emit TokensPurchased(msg.sender, totalUSDTSpent, tokensToBuy);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be > 0");

        if (token == address(usdt)) {
            require(ERC20Upgradeable(token).transfer(owner(), amount), "Transfer failed");
        } else {
            (bool success, ) = token.call(
                abi.encodeWithSignature("transfer(address,uint256)", owner(), amount)
            );
            require(success, "Transfer failed");
        }

        emit EmergencyWithdraw(token, amount);
    }

    function getTokensSoldInPhase(uint256 phaseIndex) public view returns (uint256) {
        require(phaseIndex < phases.length, "Phase index out of bounds");
        uint256 total = 0;
        for (uint256 i = 0; i < phaseIndex; i++) {
            total += phases[i].tokenLimit;
        }
        if (tokensSold <= total) return 0;
        return tokensSold - total;
    }

    function getPhaseEnd(uint256 phaseIndex) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i <= phaseIndex; i++) {
            total += phases[i].tokenLimit;
        }
        return total;
    }

    function mintTo(address recipient, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(recipient, amount);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid address");
        treasury = newTreasury;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {
        require(newImplementation != address(0), "Invalid implementation");
        require(newImplementation != address(this), "Cannot upgrade to self");
        require(msg.sender == owner(), "Only owner can upgrade");
    }

    // Optional: block ETH transfers
    receive() external payable {
        revert("Contract does not accept ETH");
    }

    fallback() external payable {
        revert("Invalid call");
    }
}