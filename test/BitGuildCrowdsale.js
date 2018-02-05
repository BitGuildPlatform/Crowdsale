var Crowdsale = artifacts.require("./BitGuildCrowdsale.sol");
var Token = artifacts.require("./BitGuildToken.sol");

var async = require('async');
var config = require('../truffle.js');

contract('BitGuildCrowdsale', function(accounts) {

  var unlockedAccounts = 5;
  const gasPrice = config.networks.development.gasPrice;
  const walletAccount = unlockedAccounts - 1;
  const adminAccount = unlockedAccounts - 2;
  const digits = 1000000000000000000;
  
  function executePromises(checks) {
    return new Promise((resolve, reject) => {
      async.eachSeries(checks,
        (check, callbackEach) => {
          check().then(function(result) {
            callbackEach(null);
          });
        },
        () => {
          resolve();
        });
    });
  }
  
  it("Whitelist", function() {
    
    var token;
    var crowdsale;
    
    return Token.new({from: accounts[adminAccount]}).then(function(instance) {
    
      token = instance;
      return Crowdsale.new(Date.now()/1000 + 100, Date.now(1000) + 200, token.address, accounts[walletAccount], {from: accounts[adminAccount]});
    
    }).then(function(instance) {
    
      crowdsale = instance;
      return crowdsale.whitelistAddress([accounts[0]], true, {from: accounts[adminAccount]});
      
    }).then(function() {
    
      var checks = [
        function() { return crowdsale.whitelist.call(accounts[0]).then(function(result) {
          assert.equal(result, true, "Account should have been whitelisted");
        }) }
      ];
      
      return executePromises(checks);
      
    });
  });
  
  // TODO: more tests to be added here before the crowdsale
  
  
});
