pragma solidity ^0.4.24;

contract Lottery {
    address owner;
    constructor(address _owner) public {
        owner = _owner;
    }
    // TODO change it ASAP - this function is highly unsecure
    function random() private view returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)))%251);
    }
}