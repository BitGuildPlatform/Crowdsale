pragma solidity ^0.4.19;

import "./SafeMath.sol";

/**
 * @title Token interface, we need just one method
 */

contract BitGuildToken {
  function transfer(address to, uint256 value) public returns (bool);
  function balanceOf(address who) public view returns (uint256);
}

/**
 * @title BitGuildCrowdsale
 * Capped crowdsale with a stard/end date
 */
contract BitGuildCrowdsale {
  using SafeMath for uint256;

  // Token being sold
  BitGuildToken public token;

  // Admin (used only to manage whitelist/finalization)
  address admin;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // Crowdsale cap (how much can be raised total)
  uint256 public cap = 2500 ether;

  // Address where funds are collected
  address public wallet;

  // Predefined rate of PLAT to Ethereum (1/rate = crowdsale price)
  uint256 public rate = 90843;

  // amount of raised money in wei
  uint256 public weiRaised;

  // whitelist for KYC purposes
  mapping (address => bool) public whitelist;
  uint256 public totalWhitelisted = 0;

  // Finalization flag for when we want to withdraw the remaining tokens after the end
  bool public crowdsaleFinalized = false;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  function BitGuildCrowdsale(uint256 _startTime, uint256 _endTime, address _token, address _wallet) public {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_token != address(0));
    require(_wallet != address(0));

    admin = msg.sender;
    startTime = _startTime;
    endTime = _endTime;
    token = BitGuildToken(_token);
    wallet = _wallet;
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(whitelist[beneficiary]);
    require(validPurchase());

    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = getTokenAmount(weiAmount);

    // update state
    weiRaised = weiRaised.add(weiAmount);

    // Send tokens
    token.transfer(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    // Send funds
    wallet.transfer(msg.value);
  }

  // Returns true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    bool capReached = weiRaised >= cap;
    bool endTimeReached = now > endTime;
    return capReached || endTimeReached || crowdsaleFinalized;
  }

  // Bonuses for larger purchases (in tenths of percent)
  function bonusPercentForWeiAmount(uint256 weiAmount) public pure returns(uint256) {
    if (weiAmount >= 250 ether) return 175; // 17.5%
    if (weiAmount >= 100 ether) return 150; // 15%
    if (weiAmount >= 50 ether) return 125;  // 12.5%
    if (weiAmount >= 25 ether) return 100;  // 10%
    if (weiAmount >= 12 ether) return 75;   // 7.5%
    if (weiAmount >= 5 ether) return 50;    // 5%
    if (weiAmount >= 1 ether) return 25;    // 2.5%
    return 0; // 0% bonus if lower than 1 eth
  }

  // Returns you how much tokens do you get for the wei passed
  function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {
    uint256 tokens = weiAmount.mul(rate);
    uint256 bonus = bonusPercentForWeiAmount(weiAmount);
    tokens = tokens.mul(1000 + bonus).div(1000);
    return tokens;
  }

  // Returns true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = weiRaised.add(msg.value) <= cap;

    return withinPeriod && nonZeroPurchase && withinCap && !crowdsaleFinalized;
  }

  // Allows an admin to update whitelist
  function whitelistAddress(address[] _users, bool _whitelisted) public {
    require(msg.sender == admin);
    for (uint i = 0; i < _users.length; i++) {
      if (whitelist[_users[i]] == _whitelisted) continue;
      if (_whitelisted) {
        totalWhitelisted++;
      } else {
        if (totalWhitelisted > 0) {
          totalWhitelisted--;
        }
      }
      whitelist[_users[i]] = _whitelisted;
    }
  }

  // Escape hatch in case the sale needs to be urgently stopped
  function finalizeCrowdsale() public {
    require(msg.sender == admin);
    crowdsaleFinalized = true;
    // send remaining tokens back to the admin
    uint256 tokensLeft = token.balanceOf(this);
    token.transfer(wallet, tokensLeft);
  }
}