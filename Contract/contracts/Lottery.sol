pragma solidity ^0.4.24;

contract Lottery {
    // Fields
    address public owner;
    LotteryGame[] public lotteries;
    Participation[] public participations;

    // Enums
    enum LotteryStatus { Finished, Active }

    // Structs

    struct Participation {
        address participant;
        uint deposit;
        uint joinedOn;

        uint reward;
        bool canWithdraw;

        uint16 longitude;
        uint16 latitude;

        uint lotteryId;
    }

    struct LotteryGame {
        address creator;

        LotteryStatus status;

        uint raisedFunds;

        uint launchedOn;
        uint finishesOn;

        uint32 maxLocationsNumber;
        uint minDeposit;

        uint winningAreaDepositsSum;

        address[] participants;

        // Lottery region params
        uint16 latitudeMin;
        uint16 latitudeMax;
        uint16 longitudeMin;
        uint16 longitudeMax;

        bytes32 region;

        uint16 winningAreaRadius;

        uint16 winningLat;
        uint16 winningLong;
    }

    // modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this method");
        _;
    }

    modifier lotteryExists(uint _lotteryId) {
        require(lotteries.length - 1 >= _lotteryId, "Lottery with the given ID does not exist");
        _;
    }

    modifier lotteryIsActive(uint _lotteryId) {
        require(lotteries[_lotteryId].status == LotteryStatus.Active && lotteries[_lotteryId].finishesOn > now, "Lottery with the given ID does not exist");
        _;
    }

    modifier lotteryIsNotFull(uint _lotteryId) {
        require(lotteries[_lotteryId].maxLocationsNumber >= lotteries[_lotteryId].participants.length, "Lottery is full");
        _;
    }

    modifier enoughDeposit(uint _lotteryId) {
        require(msg.value >= lotteries[_lotteryId].minDeposit, "The transaction amount needs to be higher than the game minimum deposit");
        _;
    }

    modifier lotteryFinished(uint _lotteryId) {
        require(lotteries[_lotteryId].finishesOn < now, "Lottery is still active");
        _;
    }

    modifier participationExists(uint _participationId) {
        require(participations.length - 1 > _participationId, "Participation with the given id does not exist");
        _;
    }
    modifier lotteryStatusFinished(uint _lotteryId) {
        require(lotteries[_lotteryId].status == LotteryStatus.Finished, "Lottery status is still active");
        _;
    }

    modifier isWinner(uint _participationId) {
        require(participations[_participationId].participant == msg.sender, "Only the participation sender can call this function");
        _;
    }

    modifier isWon(uint _participationId) {
        require(participations[_participationId].reward != 0, "To call this method the participatio needs to be a winner");
        _;
    }

    // Events

    event LotteryCreation(
        bytes32 region, 
        uint16 latitudeMin, 
        uint16 latitudeMax, 
        uint16 longitudeMin, 
        uint16 longitudeMax, 
        uint minDeposit, 
        uint64 maxLocationsNumber, 
        uint startedOn, 
        uint endsOn,
        uint16 winningAreaRadius,
        uint lotteryId
    );
 
    event LotteryJoin(
        address emiter,
        uint lotteryId,
        uint16 latitude,
        uint16 longitude,
        uint deposit,
        uint when,
        uint participationId
    );

    event LotteryFinished(
        uint lotteryId
    );

    event LotteryWin(
        address winner,
        uint reward,
        uint lotteryId,
        uint participationId
    );

    // Methods

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
        uint32 _maxLocationsNumber,
        uint _endTime, 
        uint16 _winningAreaRadius
        ) public onlyOwner() {

        uint lotteryId = lotteries.push(LotteryGame({
            creator: msg.sender,
            status: LotteryStatus.Active,
            launchedOn: now,
            finishesOn: _endTime,
            maxLocationsNumber: _maxLocationsNumber,
            minDeposit: _minDeposit,
            latitudeMin: _latitudeMin,
            latitudeMax: _latitudeMax,
            longitudeMin: _longitudeMin,
            longitudeMax: _longitudeMax,
            winningAreaRadius: _winningAreaRadius,
            participants: new address[](0),
            region: _region,
            winningLat: 0,
            winningLong: 0,
            raisedFunds: 0,
            winningAreaDepositsSum: 0
        }));

        emit LotteryCreation(
            _region,
            _latitudeMin,
            _latitudeMax,
            _longitudeMin,
            _longitudeMax,
            _minDeposit,
            _maxLocationsNumber,
            now,
            _endTime,
            _winningAreaRadius,
            lotteryId);
    }

    function joinLottery(uint _lotteryId, uint16 _lat, uint16 _long) public payable
    lotteryExists(_lotteryId)
    lotteryIsActive(_lotteryId)
    lotteryIsNotFull(_lotteryId)
    enoughDeposit(_lotteryId)
    {
        uint participationId = participations.push(Participation({
            participant: msg.sender,
            deposit: msg.value,
            joinedOn: now,
            longitude: _long,
            latitude: _lat,
            lotteryId: _lotteryId,
            reward: 0,
            canWithdraw: false
        }));

        lotteries[_lotteryId].raisedFunds += msg.value;

        emit LotteryJoin(
            msg.sender,
            _lotteryId,
            _lat,
            _long,
            msg.value,
            now,
            participationId
        );
    }

    function endLottery(uint _lotteryId) public
    lotteryExists(_lotteryId)
    lotteryFinished(_lotteryId)
    {   
        lotteries[_lotteryId].status = LotteryStatus.Finished;
        (uint16 winningLong, uint16 winningLat) = setWinningPoint(_lotteryId);
        lotteries[_lotteryId].winningLong = winningLong;
        lotteries[_lotteryId].winningLat = winningLat;
        lotteries[_lotteryId].winningAreaDepositsSum = countDepositsInWinningArea(_lotteryId);
        emit LotteryFinished(_lotteryId);
    }

    function didWon(uint _participationId) public
    participationExists(_participationId)
    lotteryExists(participations[_participationId].lotteryId)
    lotteryFinished(participations[_participationId].lotteryId)
    lotteryStatusFinished(participations[_participationId].lotteryId)
    returns(bool)
    {
        // Set participation to winning point

        int latSubstraction = int(lotteries[participations[_participationId].lotteryId].winningLat) - int(participations[_participationId].latitude);

        int longSubPow = int(lotteries[participations[_participationId].lotteryId].winningLong) - int(participations[_participationId].longitude) * int(lotteries[participations[_participationId].lotteryId].winningLong) - int(participations[_participationId].longitude);
        int latSubPow = int(lotteries[participations[_participationId].lotteryId].winningLat) - int(participations[_participationId].latitude) * int(lotteries[participations[_participationId].lotteryId].winningLat) - int(participations[_participationId].latitude);

        uint distance = sqrt(uint(longSubPow + latSubPow));

        if(distance < lotteries[participations[_participationId].lotteryId].winningAreaRadius) {
            participations[_participationId].reward = (participations[_participationId].deposit * 100) / (lotteries[participations[_participationId].lotteryId].winningAreaDepositsSum * 100);
            participations[_participationId].canWithdraw = true;
            return true;
        }
        participations[_participationId].reward = 0;
        participations[_participationId].canWithdraw = false;
        return false;
    }

    // TODO
    function withdrawReward(uint _participationId) public
    participationExists(_participationId)
    lotteryExists(participations[_participationId].lotteryId)
    lotteryFinished(participations[_participationId].lotteryId)
    lotteryStatusFinished(participations[_participationId].lotteryId)
    isWinner(_participationId)
    isWon(_participationId)
    {   
        // lotteries[participations[_participationId].lotteryId].creator.transfer((participations[_participationId].reward) * 1/20);
        msg.sender.transfer((participations[_participationId].reward) * 19/20);
    }

    function setWinningPoint(uint _lotteryId) internal returns(uint16, uint16) {
        uint16 winningLong = randomInRange(lotteries[_lotteryId].longitudeMin, lotteries[_lotteryId].longitudeMax);
        uint16 winningLat = randomInRange(lotteries[_lotteryId].latitudeMin, lotteries[_lotteryId].latitudeMax);
        return (winningLong, winningLat);
    }

    function countDepositsInWinningArea(uint _lotteryId) internal returns(uint) {
        uint result;
        for(uint i = 0; i < participations.length; i++) {
            if(participations[i].lotteryId == _lotteryId) {
                // Set participation to winning point

                int longSubstraction = int(lotteries[_lotteryId].winningLong) - int(participations[i].longitude);
                int latSubstraction = int(lotteries[_lotteryId].winningLat) - int(participations[i].latitude);

                int longSubPow = longSubstraction * longSubstraction;
                int latSubPow = latSubstraction * latSubstraction;

                uint distance = sqrt(uint(longSubPow + latSubPow));

                if(distance < lotteries[_lotteryId].winningAreaRadius) {
                    result += participations[i].deposit;
                }
            }
        }
        return result;
    }

    function sqrt(uint x) private view returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function randomInRange(uint16 min, uint16 max) internal returns(uint16) {
        uint rand = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
        return uint16(rand % (max - min + 1));
    }
}