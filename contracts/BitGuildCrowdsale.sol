pragma solidity ^0.4.19;

import "./SafeMath.sol";
import "./BitGuildToken.sol";
import "./BitGuildWhitelist.sol";

/**
 * @title BitGuildCrowdsale
 * Capped crowdsale with a stard/end date
 */
contract BitGuildCrowdsale {
  using SafeMath for uint256;

  // Token being sold
  BitGuildToken public token;

  // Whitelist being used
  BitGuildWhitelist public whitelist;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // Crowdsale cap (how much can be raised total)
  uint256 public cap = 14062.5 ether;

  // Address where funds are collected
  address public wallet;

  // Predefined rate of PLAT to Ethereum (1/rate = crowdsale price)
  uint256 public rate = 80000;

  // Min/max purchase
  uint256 public minContribution = 0.5 ether;
  uint256 public maxContribution = 1500 ether;

  // amount of raised money in wei
  uint256 public weiRaised;
  mapping (address => uint256) public contributions;

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

  function BitGuildCrowdsale(uint256 _startTime, uint256 _endTime, address _token, address _wallet, address _whitelist) public {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_token != address(0));
    require(_wallet != address(0));
    require(_whitelist != address(0));

    startTime = _startTime;
    endTime = _endTime;
    token = BitGuildToken(_token);
    wallet = _wallet;
    whitelist = BitGuildWhitelist(_whitelist);
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(whitelist.whitelist(beneficiary));
    require(validPurchase());

    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = getTokenAmount(weiAmount);

    // update total and individual contributions
    weiRaised = weiRaised.add(weiAmount);
    contributions[beneficiary] = contributions[beneficiary].add(weiAmount);

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

  // Bonuses for larger purchases (in hundredths of percent)
  function bonusPercentForWeiAmount(uint256 weiAmount) public pure returns(uint256) {
    if (weiAmount >= 500 ether) return 1000; // 10%
    if (weiAmount >= 250 ether) return 750;  // 7.5%
    if (weiAmount >= 100 ether) return 500;  // 5%
    if (weiAmount >= 50 ether) return 375;   // 3.75%
    if (weiAmount >= 15 ether) return 250;   // 2.5%
    if (weiAmount >= 5 ether) return 125;    // 1.25%
    return 0; // 0% bonus if lower than 5 eth
  }

  // Returns you how much tokens do you get for the wei passed
  function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {
    uint256 tokens = weiAmount.mul(rate);
    uint256 bonus = bonusPercentForWeiAmount(weiAmount);
    tokens = tokens.mul(10000 + bonus).div(10000);
    return tokens;
  }

  // Returns true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool moreThanMinPurchase = msg.value >= minContribution;
    bool lessThanMaxPurchase = contributions[msg.sender] + msg.value <= maxContribution;
    bool withinCap = weiRaised.add(msg.value) <= cap;

    return withinPeriod && moreThanMinPurchase && lessThanMaxPurchase && withinCap && !crowdsaleFinalized;
  }

  // Escape hatch in case the sale needs to be urgently stopped
  function finalizeCrowdsale() public {
    require(msg.sender == wallet);
    crowdsaleFinalized = true;
    // send remaining tokens back to the admin
    uint256 tokensLeft = token.balanceOf(this);
    token.transfer(wallet, tokensLeft);
  }
}