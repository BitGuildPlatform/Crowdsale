# BitGuild contracts and test suite

## Contracts

1. BitGuildToken.sol - ERC20 token, 100% standard
1. BitGuildCrowdsale.sol - crowdsale contract, based on Zeppelin crowdsale templates with some additions

## Testing
1. Install packages via `npm install`
2. Install [truffle](http://truffleframework.com/) 4.0.6
3. Install [testrpc](https://github.com/ethereumjs/testrpc) 3.9.2
4. Launch testrpc, unlocking first several accounts with `testrpc --secure -u 0 -u 1 -u 2 -u 3 -u 4`
5. Launch `truffle test` from command line
