var Lottery = artifacts.require("./Lottery.sol");

var owner = "0x71D437EDB75dEA9CAFdDC0151819388A2897306f";

module.exports = function(deployer) {
  deployer.deploy(Lottery, owner);
};
