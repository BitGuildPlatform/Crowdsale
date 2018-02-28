var Crowdsale = artifacts.require("./BitGuildCrowdsale.sol");
var Token = artifacts.require("./BitGuildToken.sol");

var async = require('async');
var config = require('../truffle.js');

contract('BitGuildCrowdsale', function(accounts) {

  // Data from the contract for cross-validation
  const rate = 80000;
  const bonusFor15Eth = 1.025;
  const bonusMax = 1.1;
  const capInEth = 2500;

  const failedTransactionError = "Error: VM Exception while processing transaction: invalid opcode";

  var unlockedAccounts = 5;
  const gasPrice = config.networks.development.gasPrice;
  const walletAccount = unlockedAccounts - 1;
  const adminAccount = unlockedAccounts - 2;
  const tokensAllocated = capInEth * web3.toWei(1, "ether") * rate * bonusMax;

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

  function delay(t, v) {
    return new Promise(function(resolve) {
      setTimeout(resolve.bind(null, v), t)
    });
  }

  function prepareCrowdsaleAndWhitelist(startDate, endDate) {
    var token;
    var crowdsale;
    return Token.new({from: accounts[adminAccount]}).then(function(instance) {
      token = instance;
      return Crowdsale.new(startDate, endDate, token.address, accounts[walletAccount], {from: accounts[adminAccount]});
    }).then(function(instance) {
      crowdsale = instance;
      token.transfer(crowdsale.address, tokensAllocated, {from: accounts[adminAccount]});
    }).then(function(result) {
      return crowdsale.whitelistAddress([accounts[0]], true, {from: accounts[adminAccount]});
    }).then(function(result) {
      return {token: token, crowdsale: crowdsale};
    });
  }

  it("Whitelist check", function() {

    var token;
    var crowdsale;

    return prepareCrowdsaleAndWhitelist(Date.now()/1000 + 100, Date.now()/1000 + 200).then(function(result) {

      token = result.token;
      crowdsale = result.crowdsale;

      var checks = [
        function() { return crowdsale.whitelist.call(accounts[0]).then(function(result) {
          assert.equal(result, true, "Account should have been whitelisted");
        }) },
        function() { return crowdsale.totalWhitelisted.call().then(function(result) {
          assert.equal(result.toNumber(), 1, "Number of whitelisted accounts is incorrect");
        }) }
      ];

      return executePromises(checks);

    });
  });

  it("Small purchases", function() {

    var token;
    var crowdsale;
    var amountWei = web3.toWei(0.5, "ether");

    return prepareCrowdsaleAndWhitelist(Date.now()/1000, Date.now()/1000 + 200).then(function(result) {

      token = result.token;
      crowdsale = result.crowdsale;

      return web3.eth.sendTransaction({from: accounts[0], to:crowdsale.address, value: amountWei, gas: 200000});

    }).then(function(result) {

      return web3.eth.sendTransaction({from: accounts[0], to:crowdsale.address, value: amountWei, gas: 200000});

    }).then(function(result) {

      var checks = [
        function() { return token.balanceOf.call(accounts[0]).then(function(result) {
          assert.equal(result.toNumber(), rate * amountWei * 2, "Wrong number of tokens purchased");
        }) },
        function() { return crowdsale.contributions.call(accounts[0]).then(function(result) {
          assert.equal(result.toNumber(), amountWei * 2, "Wrong contribution captured");
        }) }
      ];

      return executePromises(checks);

    });
  });

  it("Larger purchase", function() {

    var token;
    var crowdsale;
    var amountWei = 15 * web3.toWei(1, "ether");

    return prepareCrowdsaleAndWhitelist(Date.now()/1000, Date.now()/1000 + 200).then(function(result) {

      token = result.token;
      crowdsale = result.crowdsale;

      return web3.eth.sendTransaction({from: accounts[0], to:crowdsale.address, value: amountWei, gas: 200000});

    }).then(function(result) {

      var checks = [
        function() { return token.balanceOf.call(accounts[0]).then(function(result) {
          assert.equal(result.toNumber(), rate * amountWei * bonusFor15Eth, "Wrong number of tokens purchased");
        }) }
      ];

      return executePromises(checks);

    });
  });

  it("Failed purchase: crowdsale not started", function() {

    var token;
    var crowdsale;
    var amountWei = 100;

    return prepareCrowdsaleAndWhitelist(Date.now()/1000 + 100, Date.now()/1000 + 200).then(function(result) {

      token = result.token;
      crowdsale = result.crowdsale;

      return web3.eth.sendTransaction({from: accounts[0], to:crowdsale.address, value: amountWei});

    }).then(function(result) {

      assert(false, "Transaction passed, it should not had");

    }, function(error) {

      assert.equal(error, failedTransactionError, "Incorrect error");

    });
  });

  it("Failed purchase: crowdsale ended", function() {

    var token;
    var crowdsale;
    var amountWei = 100;

    return prepareCrowdsaleAndWhitelist(Date.now()/1000, Date.now()/1000).then(function(result) {

      token = result.token;
      crowdsale = result.crowdsale;

      return delay(1200);

    }).then(function(result) {

      return web3.eth.sendTransaction({from: accounts[0], to:crowdsale.address, value: amountWei});

    }).then(function(result) {

      assert(false, "Transaction passed, it should not had");

    }, function(error) {

      assert.equal(error, failedTransactionError, "Incorrect error");

    });
  });

  it("Failed purchase: cap reached", function() {

    var token;
    var crowdsale;
    var amountWei = (capInEth + 1) * web3.toWei(1, "ether");;

    return prepareCrowdsaleAndWhitelist(Date.now()/1000, Date.now()/1000 + 5).then(function(result) {

      token = result.token;
      crowdsale = result.crowdsale;

      return web3.eth.sendTransaction({from: accounts[0], to:crowdsale.address, value: amountWei});

    }).then(function(result) {

      assert(false, "Transaction passed, it should not had");

    }, function(error) {

      assert.equal(error, failedTransactionError, "Incorrect error");

    });
  });

  it("Failed purchase: account not whitelisted", function() {

    var token;
    var crowdsale;
    var amountWei = 100;

    return prepareCrowdsaleAndWhitelist(Date.now()/1000, Date.now()/1000 + 200).then(function(result) {

      token = result.token;
      crowdsale = result.crowdsale;

      return web3.eth.sendTransaction({from: accounts[1], to:crowdsale.address, value: amountWei});

    }).then(function(result) {

      assert(false, "Transaction passed, it should not had");

    }, function(error) {

      assert.equal(error, failedTransactionError, "Incorrect error");

    });

  });

});
