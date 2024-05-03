// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import "../lib/Math64x64.sol";
import "./Demurrage.sol";

contract DiscountedBalances is Demurrage {
    // State variables

    /**
     * @dev stores the discounted balances of the accounts privately.
     * Mapping from Circles identifiers to accounts to the discounted balance.
     */
    mapping(uint256 => mapping(address => DiscountedBalance)) internal discountedBalances;

    /**
     * @dev stores the total supply for each Circles identifier
     */
    mapping(uint256 => DiscountedBalance) internal discountedTotalSupplies;

    // Constructor

    /**
     * @dev Constructor to set the start of the global inflationary curve.
     * @param _inflation_day_zero Timestamp of midgnight day zero for the global inflationary curve.
     */
    constructor(uint256 _inflation_day_zero) {
        inflationDayZero = _inflation_day_zero;
    }

    // Public functions

    /**
     * @notice Balance of a Circles identifier for a given account on a (future) day.
     * @param _account Address of the account to calculate the balance of
     * @param _id Circles identifier for which to calculate the balance
     * @param _day Day since inflation_day_zero to calculate the balance for
     */
    function balanceOfOnDay(address _account, uint256 _id, uint64 _day) public view returns (uint256) {
        DiscountedBalance memory discountedBalance = discountedBalances[_id][_account];
        return _calculateDiscountedBalance(discountedBalance.balance, _day - discountedBalance.lastUpdatedDay);
    }

    /**
     * @notice Total supply of a Circles identifier.
     * @param _id Circles identifier for which to calculate the total supply
     */
    function totalSupply(uint256 _id) public view returns (uint256) {
        DiscountedBalance memory totalSupplyBalance = discountedTotalSupplies[_id];
        uint64 today = day(block.timestamp);
        return _calculateDiscountedBalance(totalSupplyBalance.balance, today - totalSupplyBalance.lastUpdatedDay);
    }

    // Internal functions

    /**
     * @dev Update the balance of an account for a given Circles identifier
     * @param _account Address of the account to update the balance of
     * @param _id Circles identifier for which to update the balance
     * @param _balance New balance to set
     * @param _day Day since inflation_day_zero to set as last updated day
     */
    function _updateBalance(address _account, uint256 _id, uint256 _balance, uint64 _day) internal {
        if (_balance > MAX_VALUE) {
            // DiscountedBalances: balance exceeds maximum value
            revert CirclesERC1155AmountExceedsMaxUint190(_account, _id, _balance, 0);
        }
        DiscountedBalance storage discountedBalance = discountedBalances[_id][_account];
        discountedBalance.balance = uint192(_balance);
        discountedBalance.lastUpdatedDay = _day;
    }

    /**
     * @dev Discount to the given day and add to the balance of an account for a given Circles identifier
     * @param _account Address of the account to update the balance of
     * @param _id Circles identifier for which to update the balance
     * @param _value Value to add to the discounted balance
     * @param _day Day since inflation_day_zero to discount the balance to
     */
    function _discountAndAddToBalance(address _account, uint256 _id, uint256 _value, uint64 _day) internal {
        DiscountedBalance storage discountedBalance = discountedBalances[_id][_account];
        uint256 discountedBalanceValue =
            _calculateDiscountedBalance(discountedBalance.balance, _day - discountedBalance.lastUpdatedDay);
        uint256 newBalance = discountedBalanceValue + _value;
        if (newBalance > MAX_VALUE) {
            // DiscountedBalances: balance exceeds maximum value
            revert CirclesERC1155AmountExceedsMaxUint190(_account, _id, newBalance, 1);
        }
        discountedBalance.balance = uint192(newBalance);
        discountedBalance.lastUpdatedDay = _day;
    }
}
