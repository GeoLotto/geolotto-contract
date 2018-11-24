pragma solidity ^0.4.24;

contract Lottery {

    // Fields

    address owner;
    mapping(bytes32 => Lottery) public lotteries;

    // Types

    struct LotteryParticipation {
        uint16[2] position;
        uint256 deposit;
        uint participationTime; // timestamp
    }

    struct Lottery {
        uint launchTime; // timestamp
        uint endTime; // timestamp

        uint raisedFunds;

        // Lottery participants
        uint64 maxMembersNumber;
        address[] participants;
        mapping(address => LotteryParticipation[]) participations;

        uint minDeposit;
        uint16[2] winningPoint;

        // Lottery region params
        uint16 latitudeMin;
        uint16 latitudeMax;
        uint16 longitudeMin;
        uint16 longitudeMax;
    }

    // Events

    event LotteryCreation(
        bytes32 region, 
        uint16 latitudeMin, 
        uint16 latitudeMax, 
        uint16 longitudeMin, 
        uint16 longitudeMax, 
        uint minDeposit, 
        uint64 maxMembersNumber, 
        uint startedOn, 
        uint endsOn
    );

    event LotteryJoin(
        address who,
        bytes32 region,
        uint when
    );

    event LotteryChanceAdded(
        bytes32 region,
        address who,
        uint16 latitude,
        uint16 longitude,
        uint value,
        uint when
    );

    // Modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this method");
        _;
    }

    modifier lotteryExists(bytes32 _region) {
        require(lotteries[_region].maxMembersNumber != 0, "Lottery with the given region does not exist");
        _;
    }

    modifier lotteryNotFull(bytes32 _region) {
        require(lotteries[_region].participants.length < lotteries[_region].maxMembersNumber, "Lottery is already full");
        _;
    }

    modifier participantDoesNotExist(bytes32 _region) {
        require(lotteries[_region].participations[msg.sender].length == 0, "msg.sender is already a participant of this lottery");
        _;
    }

    modifier positionMatchesRegion(bytes32 _region, uint16 _latitude, uint16 _longitude) {
        require(
            _latitude >= lotteries[_region].latitudeMin && _latitude <= lotteries[_region].latitudeMax 
            && 
            _longitude >= lotteries[_region].longitudeMin && _longitude <= lotteries[_region].longitudeMax,
            "The given position does not match the given region"
        );
        _;
    }

    modifier lotteryActive(bytes32 _region) {
        require(lotteries[_region].endTime > now, "Lottery has already finished");
        _;
    }

    constructor(address _owner) public {
        owner = _owner;
    }

    function createNewLottery(
        bytes32 _region,
        uint16 _latitudeMin,
        uint16 _latitudeMax,
        uint16 _longitudeMin,
        uint16 _longitudeMax,
        uint _minDeposit, 
        uint _endTime, 
        uint64 _maxMembersNumber) public onlyOwner() {
        
        Lottery memory lottery;

        lottery.launchTime = now;
        lottery.endTime = _endTime;
        lottery.maxMembersNumber = _maxMembersNumber;
        lottery.minDeposit = _minDeposit;

        lottery.latitudeMin = _latitudeMin;
        lottery.latitudeMax = _latitudeMax;
        lottery.longitudeMin = _longitudeMin;
        lottery.longitudeMax = _longitudeMax;

        lotteries[_region] = lottery;

        emit LotteryCreation(
            _region,
            _latitudeMin,
            _latitudeMax,
            _longitudeMin,
            _longitudeMax,
            _minDeposit,
            _maxMembersNumber,
            now,
            _endTime);
    }

    function joinLottery(bytes32 _region, uint16 _latitude, uint16 _longitude) public payable
    lotteryExists(_region)
    lotteryNotFull(_region)
    participantDoesNotExist(_region)
    positionMatchesRegion(_region, _latitude, _longitude)
    lotteryActive(_region)
    {
        // Join

        lotteries[_region].participants.push(msg.sender);

        emit LotteryJoin(
            msg.sender,
            _region,
            now
        );

        // Assign participation to lottery

        LotteryParticipation memory participation = LotteryParticipation({
            position: [_latitude, _longitude],
            deposit: msg.value,
            participationTime: now
        });

        lotteries[_region].participations[msg.sender].push(participation);
        lotteries[_region].raisedFunds += msg.value;

        emit LotteryChanceAdded(
            _region,
            msg.sender,
            _latitude,
            _longitude,
            msg.value,
            now
        );
    }

    function addNewChance(bytes32 _region, uint16 _latitude, uint16 _longitude) public payable
    lotteryExists(_region)
    positionMatchesRegion(_region, _latitude, _longitude)
    lotteryActive(_region)
    {
        LotteryParticipation memory participation = LotteryParticipation({
            position: [_latitude, _longitude],
            deposit: msg.value,
            participationTime: now
        });

        lotteries[_region].participations[msg.sender].push(participation);
        lotteries[_region].raisedFunds += msg.value;

        emit LotteryChanceAdded(
            _region,
            msg.sender,
            _latitude,
            _longitude,
            msg.value,
            now
        );
    }
    // TODO change it ASAP - this function is highly unsecure
    function random() private view returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)))%251);
    }


}