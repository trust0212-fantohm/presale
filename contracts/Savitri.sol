// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract SalePhasedToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    struct SalePhase {
        uint256 tokenLimit;
        uint256 pricePerToken; // in USDT with 6 decimals (e.g., $0.35 = 350000)
        uint256 startTime;
        uint256 endTime;
    }

    SalePhase[] public phases;
    uint256 public currentPhase;
    uint256 public tokensSold;
    uint256 public minPurchaseAmount;
    uint256 public maxPurchaseAmount;
    mapping(address => uint256) public userPurchases;

    ERC20Upgradeable public usdt;
    address public treasury;

    uint256 public constant DECIMALS = 1e18;
    uint256 public constant MAX_SUPPLY = 240_000_000 * DECIMALS; // 240M tokens

    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount);
    event PhaseAdvanced(uint256 newPhase);
    event EmergencyWithdraw(address token, uint256 amount);

    /**
     * @dev Initializes the contract with USDT token address and treasury address
     * @param _usdt Address of the USDT token contract
     * @param _treasury Address where USDT payments will be sent
     * @param _minPurchaseAmount Minimum USDT amount for purchase (6 decimals)
     * @param _maxPurchaseAmount Maximum USDT amount for purchase (6 decimals)
     */
    function initialize(
        address _usdt, 
        address _treasury,
        uint256 _minPurchaseAmount,
        uint256 _maxPurchaseAmount
    ) public initializer {
        __ERC20_init("Savitri", "SAVI");
        __Ownable_init(msg.sender);
        __Pausable_init();

        usdt = ERC20Upgradeable(_usdt);
        treasury = _treasury;
        minPurchaseAmount = _minPurchaseAmount;
        maxPurchaseAmount = _maxPurchaseAmount;

        // Setup phases
        phases.push(SalePhase(35_000_000 * DECIMALS, 350000, 0, 0)); // $0.35
        phases.push(SalePhase(42_500_000 * DECIMALS, 400000, 0, 0)); // $0.40
        phases.push(SalePhase(21_250_000 * DECIMALS, 450000, 0, 0)); // $0.45
        phases.push(SalePhase(21_250_000 * DECIMALS, 500000, 0, 0)); // $0.50
        phases.push(SalePhase(60_000_000 * DECIMALS, 550000, 0, 0)); // $0.55
        phases.push(SalePhase(60_000_000 * DECIMALS, 600000, 0, 0)); // $0.60
    }

    /**
     * @dev Sets the start and end time for a phase
     * @param phaseIndex Index of the phase to set
     * @param startTime Unix timestamp for phase start
     * @param endTime Unix timestamp for phase end
     */
    function setPhaseTime(uint256 phaseIndex, uint256 startTime, uint256 endTime) external onlyOwner {
        require(phaseIndex < phases.length, "Invalid phase");
        require(startTime < endTime, "Invalid time range");
        phases[phaseIndex].startTime = startTime;
        phases[phaseIndex].endTime = endTime;
    }

    /**
     * @dev Allows users to buy tokens with USDT
     * @param usdtAmount Amount of USDT to spend (6 decimals)
     * @notice Automatically handles phase transitions and token distribution
     */
    function buy(uint256 usdtAmount) external whenNotPaused {
        require(usdtAmount >= minPurchaseAmount, "Amount below minimum");
        require(userPurchases[msg.sender] + usdtAmount <= maxPurchaseAmount, "Exceeds max purchase limit");
        require(currentPhase < phases.length, "Sale completed");
        
        SalePhase memory phase = phases[currentPhase];
        require(block.timestamp >= phase.startTime, "Phase not started");
        require(block.timestamp <= phase.endTime, "Phase ended");

        uint256 tokensToBuy = 0;
        uint256 remainingUSDT = usdtAmount;
        uint256 totalUSDTSpent = 0;

        while (remainingUSDT > 0 && currentPhase < phases.length) {
            phase = phases[currentPhase];
            uint256 tokensLeft = phase.tokenLimit - getTokensSoldInPhase(currentPhase);
            require(tokensLeft > 0, "No tokens left in phase");

            uint256 tokensAtPrice = (remainingUSDT * 10 ** 12) / phase.pricePerToken;
            uint256 buyingNow = tokensAtPrice > tokensLeft ? tokensLeft : tokensAtPrice;

            uint256 costForTokens = (buyingNow * phase.pricePerToken) / 10 ** 12;

            tokensToBuy += buyingNow;
            remainingUSDT -= costForTokens;
            totalUSDTSpent += costForTokens;

            tokensSold += buyingNow;
            userPurchases[msg.sender] += costForTokens;

            if (tokensSold >= getPhaseEnd(currentPhase)) {
                currentPhase++;
                emit PhaseAdvanced(currentPhase);
            } else {
                break;
            }
        }

        require(tokensToBuy > 0, "Not enough USDT to buy tokens");

        // Transfer USDT to treasury
        require(
            usdt.transferFrom(msg.sender, treasury, totalUSDTSpent),
            "USDT transfer failed"
        );

        // Refund remaining USDT if any
        if (remainingUSDT > 0) {
            require(
                usdt.transferFrom(msg.sender, msg.sender, remainingUSDT),
                "USDT refund failed"
            );
        }

        _mint(msg.sender, tokensToBuy);
        emit TokensPurchased(msg.sender, totalUSDTSpent, tokensToBuy);
    }

    /**
     * @dev Emergency withdraw function for stuck funds
     * @param token Address of the token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be > 0");
        
        if (token == address(usdt)) {
            require(ERC20Upgradeable(token).transfer(owner(), amount), "Transfer failed");
        } else {
            (bool success, ) = token.call(abi.encodeWithSignature("transfer(address,uint256)", owner(), amount));
            require(success, "Transfer failed");
        }
        
        emit EmergencyWithdraw(token, amount);
    }

    /**
     * @dev Returns the number of tokens sold in a specific phase
     * @param phaseIndex Index of the phase to check
     * @return Number of tokens sold in the specified phase
     */
    function getTokensSoldInPhase(
        uint256 phaseIndex
    ) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < phaseIndex; i++) {
            total += phases[i].tokenLimit;
        }
        if (tokensSold <= total) return 0;
        return tokensSold - total;
    }

    /**
     * @dev Returns the total number of tokens that should be sold by the end of a phase
     * @param phaseIndex Index of the phase to check
     * @return Total tokens that should be sold by the end of the phase
     */
    function getPhaseEnd(uint256 phaseIndex) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i <= phaseIndex; i++) {
            total += phases[i].tokenLimit;
        }
        return total;
    }

    /**
     * @dev Allows owner to mint tokens to a specific address
     * @param recipient Address to receive the minted tokens
     * @param amount Number of tokens to mint
     * @notice Only callable by contract owner
     */
    function mintTo(address recipient, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(recipient, amount);
    }
}
