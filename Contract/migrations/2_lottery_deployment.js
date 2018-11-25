var Lottery = artifacts.require("./Lottery.sol");

var owner = "0x1d65941b963B71daEd8d0ec52117Ce88c75C28aA";
// var owner = "0x71D437EDB75dEA9CAFdDC0151819388A2897306f";

module.exports = function(deployer) {
  deployer.deploy(Lottery, owner);
};
