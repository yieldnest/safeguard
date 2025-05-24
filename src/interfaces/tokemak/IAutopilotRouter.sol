// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

interface IAutopilotRouter {
    function claimAutopoolRewards(
        address vault,
        address rewarder,
        address recipient
    ) external;

    function deposit(
        address vault,
        address to,
        uint256 amount,
        uint256 minSharesOut
    ) external returns (uint256 sharesOut);

    function redeem(
        address vault,
        address to,
        uint256 shares,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);

    function approve(
        address token,
        address to,
        uint256 amount
    ) external;

    function stakeVaultToken(
        address token,
        uint256 maxAmount
    ) external;

    function withdrawVaultToken(
        address token,
        address rewarder,
        uint256 maxAmount,
        bool claim
    ) external;
}
