pragma solidity ^0.4.24;

contract Lottery {

    // Enums

    enum LotteryStatus { Active, Finshed }

    // Fields

    address owner;
    uint nonce = 0;
    mapping(bytes32 => Lottery) public lotteries;

    // Types

    struct LotteryParticipation {
        uint16[2] position;
        uint256 deposit;
        uint participationTime; // timestamp
    }

    struct LotteryWinnings {
        address winner;
        uint deposit;
        uint winning;
        uint8 inAreaDuePercentageRatio;
        uint8 areaWinningRatio;
    }

    struct Lottery {

        LotteryStatus status;

        uint launchTime; // timestamp
        uint endTime; // timestamp

        uint raisedFunds;

        // Lottery participants
        uint64 maxMembersNumber;
        address[] participants;
        mapping(address => LotteryParticipation[]) participations;

        // Lottery Winners

        LotteryWinnings[] winnings;

        uint minDeposit;
        uint16[2] winningPoint;
        uint16[2] winningAreasRadius;

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

    modifier userJoinedTheLottery(bytes32 _region) {
        require(lotteries[_region].participations[msg.sender].length != 0, "Lottery has not been joined");
        _;
    }

    modifier lotteryFinished(bytes32 _region) {
        require(lotteries[_region].endTime < now, "Lottery is still active");
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
        uint64 _maxMembersNumber,
        uint16 _firstWinningAreaRadius,
        uint16 _secondWinningAreaRadius) public onlyOwner() {
        
        Lottery memory lottery;

        lottery.launchTime = now;
        lottery.endTime = _endTime;
        lottery.maxMembersNumber = _maxMembersNumber;
        lottery.minDeposit = _minDeposit;

        lottery.latitudeMin = _latitudeMin;
        lottery.latitudeMax = _latitudeMax;
        lottery.longitudeMin = _longitudeMin;
        lottery.longitudeMax = _longitudeMax;

        lottery.winningAreasRadius = [_firstWinningAreaRadius, _secondWinningAreaRadius];

        lottery.status = LotteryStatus.Active;

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

    function putOnNewLocation(bytes32 _region, uint16 _latitude, uint16 _longitude) public payable
    lotteryExists(_region)
    positionMatchesRegion(_region, _latitude, _longitude)
    lotteryActive(_region)
    userJoinedTheLottery(_region)
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

    // TODO
    function endLottery(bytes32 _region) public 
    lotteryExists(_region)
    lotteryFinished(_region)
    {

    }

    // Selecting winner TODO modifiers
    function setWinners(bytes32 _region) internal {
        int16 _winningLatitude = int16(lotteries[_region].winningPoint[0]);
        int16 _winningLongitude = int16(lotteries[_region].winningPoint[1]);
        uint _actuallyIteratedWin;
        for(uint i = 0; i < lotteries[_region].participants.length; i++) {
            address checkedAddress = lotteries[_region].participants[i];
            for(uint j = 0; j < lotteries[_region].participations[checkedAddress].length; j++) {
                bool isParticipationPointInWinningArea;

                // Check if is in part.point is in main win circle

                uint distanceToWinningPoint;

                // Count this distance
                int16 _partLat = int16(lotteries[_region].participations[checkedAddress][j].position[0]);
                int16 _partLon = int16(lotteries[_region].participations[checkedAddress][j].position[1]);

                int16 _latitudesSubstraction = (_partLat - _winningLatitude);
                int16 _latitudesPoweredSubstraction = _latitudesSubstraction * _latitudesSubstraction;

                int16 _longitudesSubstraction = (_partLon - _winningLongitude);
                int16 _longitudesPoweredSubstraction = _longitudesSubstraction * _longitudesSubstraction;

                distanceToWinningPoint = sqrt(uint(_latitudesPoweredSubstraction + _longitudesPoweredSubstraction));

                if(lotteries[_region].winningAreasRadius[0] >= distanceToWinningPoint) {
                    isParticipationPointInWinningArea = true;
                    if(_actuallyIteratedWin == 0) {
                        LotteryWinnings memory winning;
                        winning.winner = checkedAddress;
                        winning.deposit = lotteries[_region].participations[checkedAddress][j].deposit;
                        winning.inAreaDuePercentageRatio = 75;
                        winning.areaWinningRatio = uint8((lotteries[_region].participations[checkedAddress][j].deposit * 100) / (getFirstWinningAreaDepositsSum(_region) * 100));
                        _actuallyIteratedWin = lotteries[_region].winnings.push(winning) - 1;

                    } else {
                        lotteries[_region].winnings[_actuallyIteratedWin].winner = checkedAddress;
                        lotteries[_region].winnings[_actuallyIteratedWin].deposit = lotteries[_region].participations[checkedAddress][j].deposit;
                        lotteries[_region].winnings[_actuallyIteratedWin].inAreaDuePercentageRatio = 25;
                        lotteries[_region].winnings[_actuallyIteratedWin].areaWinningRatio  = uint8((lotteries[_region].participations[checkedAddress][j].deposit * 100) / (getSecondWinningAreaDepositsSum(_region) * 100));
                        _actuallyIteratedWin++;
                    }
                } else if(lotteries[_region].winningAreasRadius[1] >= distanceToWinningPoint && lotteries[_region].winningAreasRadius[0] <= distanceToWinningPoint) {
                    isParticipationPointInWinningArea = true;
                    if(_actuallyIteratedWin == 0) {
                        LotteryWinnings memory winning;
                        winning.winner = checkedAddress;
                        winning.deposit = lotteries[_region].participations[checkedAddress][j].deposit;
                        winning.inAreaDuePercentageRatio = 75;
                        winning.areaWinningRatio = uint8((lotteries[_region].participations[checkedAddress][j].deposit * 100) / (getFirstWinningAreaDepositsSum(_region) * 100));
                        _actuallyIteratedWin = lotteries[_region].winnings.push(winning) - 1;

                    } else {
                        lotteries[_region].winnings[_actuallyIteratedWin].winner = checkedAddress;
                        lotteries[_region].winnings[_actuallyIteratedWin].deposit = lotteries[_region].participations[checkedAddress][j].deposit;
                        lotteries[_region].winnings[_actuallyIteratedWin].inAreaDuePercentageRatio = 25;
                        lotteries[_region].winnings[_actuallyIteratedWin].areaWinningRatio  = uint8((lotteries[_region].participations[checkedAddress][j].deposit * 100) / (getSecondWinningAreaDepositsSum(_region) * 100));
                        _actuallyIteratedWin++;
                    }
                } else {
                    isParticipationPointInWinningArea = false;
                }
            }
        }
    }

    function getFirstWinningAreaDepositsSum(bytes32 _region) internal returns(uint) {
        uint result = 0;
        int16 _winningLatitude = int16(lotteries[_region].winningPoint[0]);
        int16 _winningLongitude = int16(lotteries[_region].winningPoint[1]);
        for(uint i = 0; i < lotteries[_region].participants.length; i++) {
            address checkedAddress = lotteries[_region].participants[i];
            for(uint j = 0; j < lotteries[_region].participations[checkedAddress].length; j++) {
                // Check if is in part.point is in main win circle

                uint distanceToWinningPoint;

                // Count this distance
                int16 _partLat = int16(lotteries[_region].participations[checkedAddress][j].position[0]);
                int16 _partLon = int16(lotteries[_region].participations[checkedAddress][j].position[1]);

                int16 _latitudesSubstraction = (_partLat - _winningLatitude);
                int16 _latitudesPoweredSubstraction = _latitudesSubstraction * _latitudesSubstraction;

                int16 _longitudesSubstraction = (_partLon - _winningLongitude);
                int16 _longitudesPoweredSubstraction = _longitudesSubstraction * _longitudesSubstraction;

                distanceToWinningPoint = sqrt(uint(_latitudesPoweredSubstraction + _longitudesPoweredSubstraction));

                if(lotteries[_region].winningAreasRadius[0] >= distanceToWinningPoint) {
                    result += lotteries[_region].participations[checkedAddress][j].deposit;
                }
            }
        }
        return result;
    }

    function getSecondWinningAreaDepositsSum(bytes32 _region) internal returns(uint) {
        uint result = 0;
        int16 _winningLatitude = int16(lotteries[_region].winningPoint[0]);
        int16 _winningLongitude = int16(lotteries[_region].winningPoint[1]);
        for(uint i = 0; i < lotteries[_region].participants.length; i++) {
            address checkedAddress = lotteries[_region].participants[i];
            for(uint j = 0; j < lotteries[_region].participations[checkedAddress].length; j++) {
                // Check if is in part.point is in main win circle

                uint distanceToWinningPoint;

                // Count this distance
                int16 _partLat = int16(lotteries[_region].participations[checkedAddress][j].position[0]);
                int16 _partLon = int16(lotteries[_region].participations[checkedAddress][j].position[1]);

                int16 _latitudesSubstraction = (_partLat - _winningLatitude);
                int16 _latitudesPoweredSubstraction = _latitudesSubstraction * _latitudesSubstraction;

                int16 _longitudesSubstraction = (_partLon - _winningLongitude);
                int16 _longitudesPoweredSubstraction = _longitudesSubstraction * _longitudesSubstraction;

                distanceToWinningPoint = sqrt(uint(_latitudesPoweredSubstraction + _longitudesPoweredSubstraction));

                if(lotteries[_region].winningAreasRadius[1] >= distanceToWinningPoint && lotteries[_region].winningAreasRadius[0] <= distanceToWinningPoint) {
                    result += lotteries[_region].participations[checkedAddress][j].deposit;
                }
            }
        }
        return result;
    }

    // TODO modifiers
    function setWinningPoint(bytes32 _region) internal {
        lotteries[_region].winningPoint[0] = uint16(randomInRange(lotteries[_region].latitudeMin, lotteries[_region].latitudeMax));
        lotteries[_region].winningPoint[1] = uint16(randomInRange(lotteries[_region].longitudeMin, lotteries[_region].longitudeMax));
    }

    // TODO change it ASAP - this function is highly unsecure
    function random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
    }

    function randomInRange(uint min, uint max) private view returns (uint) {
        return random() % (max - min + 1);
    }

    function sqrt(uint x) private view returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


}