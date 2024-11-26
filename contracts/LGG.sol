// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LGGToken is ERC20, ERC20Burnable, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Constants
    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    
    // Fee configuration
    uint256 public marketingFee = 2; // 2%
    uint256 public liquidityFee = 3; // 3%
    address public marketingWallet;
    
    // Trading limits
    uint256 public maxTransactionAmount;
    uint256 public maxWalletSize;
    
    // Mappings
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isBlacklisted;
    
    // Events
    event MarketingWalletUpdated(address newWallet);
    event FeesUpdated(uint256 marketingFee, uint256 liquidityFee);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event MaxLimitsUpdated(uint256 maxTx, uint256 maxWallet);

    constructor(address _marketingWallet) ERC20("LugIt.co", "LGG") {
        require(_marketingWallet != address(0), "Marketing wallet cannot be zero");
        
        // Set up roles first
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        // Initialize core variables
        marketingWallet = _marketingWallet;
        maxTransactionAmount = TOTAL_SUPPLY / 100; // 1%
        maxWalletSize = TOTAL_SUPPLY / 50;        // 2%
        
        // Set fee exclusions before minting
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[_marketingWallet] = true;
        
        // Mint initial supply last
        _mint(msg.sender, TOTAL_SUPPLY);
    }
    
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        // Check basic requirements
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }
        
        require(!isBlacklisted[from] && !isBlacklisted[to], "Address is blacklisted");
        
        if (!isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            require(amount <= maxTransactionAmount, "Exceeds max transaction amount");
            require(balanceOf(to) + amount <= maxWalletSize, "Exceeds max wallet size");
            
            uint256 marketingTokens = (amount * marketingFee) / 100;
            uint256 liquidityTokens = (amount * liquidityFee) / 100;
            uint256 totalFee = marketingTokens + liquidityTokens;
            
            if (totalFee > 0) {
                super._update(from, marketingWallet, marketingTokens);
                super._update(from, address(this), liquidityTokens);
                super._update(from, to, amount - totalFee);
                return;
            }
        }
        
        super._update(from, to, amount);
    }
    
    // Admin functions
    function setMarketingWallet(address _marketingWallet) external onlyRole(ADMIN_ROLE) {
        require(_marketingWallet != address(0), "Marketing wallet cannot be zero");
        marketingWallet = _marketingWallet;
        emit MarketingWalletUpdated(_marketingWallet);
    }
    
    function setFees(uint256 _marketingFee, uint256 _liquidityFee) external onlyRole(ADMIN_ROLE) {
        require(_marketingFee + _liquidityFee <= 10, "Total fees cannot exceed 10%");
        marketingFee = _marketingFee;
        liquidityFee = _liquidityFee;
        emit FeesUpdated(_marketingFee, _liquidityFee);
    }
    
    function setMaxLimits(uint256 _maxTxAmount, uint256 _maxWalletSize) external onlyRole(ADMIN_ROLE) {
        require(_maxTxAmount >= TOTAL_SUPPLY / 1000, "Max TX too low");
        require(_maxWalletSize >= TOTAL_SUPPLY / 1000, "Max wallet too low");
        maxTransactionAmount = _maxTxAmount;
        maxWalletSize = _maxWalletSize;
        emit MaxLimitsUpdated(_maxTxAmount, _maxWalletSize);
    }
    
    // Blacklist management
    function setBlacklist(address account, bool blacklisted) external onlyRole(ADMIN_ROLE) {
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }
    
    // Fee exclusion management
    function setFeeExclusion(address account, bool excluded) external onlyRole(ADMIN_ROLE) {
        isExcludedFromFee[account] = excluded;
    }
    
    // Emergency functions
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    // Required override
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}