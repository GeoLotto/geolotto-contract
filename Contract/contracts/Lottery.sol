pragma solidity ^0.5.0;

contract Lottery {
    enum CouponState { Pending, Lost, AwaitingClaim, Claimed }
    enum LotteryState { Finished, Active }
    LotteryState state = LotteryState.Active;
    address owner;
    uint endTime;

    uint depositsInWinningArea;

    uint winningRadius;

    uint winningLongitude;
    uint winningLatitude;

    uint maxLatitude;
    uint minLatitude;

    uint maxLongitude;
    uint minLongitude;

    Coupon[] public coupons;

    // Structs

    struct Coupon {
        uint longitude;
        uint latitude;

        address emiter;

        uint value;

        uint timestamp;

        CouponState state;

        uint reward;
    }

    // Events

    event CouponsGetting(
        uint couponsNumber
    );

    event NewCoupon(
        address emiter,
        uint value,
        uint longitude,
        uint latitude,
        uint joined,
        uint couponId
    );

    event AwaitingWin(
        uint couponId,
        address winner,
        uint reward
    );

    event Claimed(
        uint couponId,
        address winner,
        uint reward
    );

    event Lost(
        uint couponId,
        address looser
    );

    event LotteryFinished(
        uint when
    );

    // Modifiers

    modifier isFinished() {
        require(now > endTime, "Lottery is still active");
        _;
    }

    modifier isActive() {
        require(state == LotteryState.Active, "Lottery is not active");
        _;
    }

    modifier couponExists(uint _couponId) {
        require(coupons.length - 1 > _couponId, "Coupon does nort exist");
        _;
    }

    modifier isCouponOwner(uint _couponId) {
        require(coupons[_couponId].emiter == msg.sender, "This function can be called just by the coupon owner");
        _;
    }

    modifier couponAwaiting(uint _couponId) {
        require(coupons[_couponId].state == CouponState.AwaitingClaim, "Coupon needs to be claimed");
        _;
    }

    // Methods

    constructor(
        address _owner, 
        uint _winningRadius, 
        uint _endTime, 
        uint _maxLatitude, 
        uint _minLatitude, 
        uint _maxLongitude, 
        uint _minLongitude) 
        public 
    {
        owner = _owner;
        winningRadius = _winningRadius;
        endTime = _endTime;
        maxLongitude = _maxLongitude;
        minLongitude = _minLongitude;
        maxLongitude = _maxLatitude;
        minLatitude = _minLatitude;
    }

    function getCouponsNumbers() public view  returns(uint) {
        return coupons.length;
    }

    function addNewCoupon(uint _longitude, uint _latitude) public payable
    isActive()
    {
        uint couponId = coupons.push(Coupon({
            longitude: _longitude,
            latitude: _latitude,
            emiter: msg.sender,
            timestamp: now,
            state: CouponState.Pending,
            value: msg.value,
            reward: 0
        }));

        emit NewCoupon(
            msg.sender,
            msg.value,
            _longitude,
            _latitude,
            now,
            couponId
        );
    }

    function endLottery() public 
    isFinished()
    {
        state = LotteryState.Finished;
        uint nonce = 0;
        winningLongitude = randomInRange(minLongitude ,maxLongitude, nonce);
        nonce++;
        winningLatitude = randomInRange(minLatitude ,maxLatitude, nonce);
        depositsInWinningArea = countDepositsInWinningArea();
        emit LotteryFinished(now);
    }

    function didWon(uint _couponId) public
    isFinished()
    couponExists(_couponId)
    {
        int latSub = int(winningLatitude) - int(coupons[_couponId].latitude);
        int longSub = int(winningLongitude) - int(coupons[_couponId].longitude);

        uint distance = sqrt(uint((latSub * latSub) + (longSub * longSub)));

        if(distance < winningRadius) {
            coupons[_couponId].state = CouponState.AwaitingClaim;
            uint reward = (coupons[_couponId].value*100)/(depositsInWinningArea*100);
            coupons[_couponId].reward = reward;
            emit AwaitingWin(_couponId, coupons[_couponId].emiter, reward);
        } else {
            coupons[_couponId].state = CouponState.Lost;
            emit Lost(_couponId, coupons[_couponId].emiter);
        }
    }

    function requestReward(uint _couponId) public
    isFinished()
    couponExists(_couponId)
    isCouponOwner(_couponId)
    couponAwaiting(_couponId)
    {
        msg.sender.transfer(coupons[_couponId].reward * 19/20);
        emit AwaitingWin(_couponId, coupons[_couponId].emiter, coupons[_couponId].reward * 19/20);
    }

    function countDepositsInWinningArea() internal view returns(uint) {
        uint result;
        for(uint i = 0; i < coupons.length; i++) {
            int latSub = int(winningLatitude) - int(coupons[i].latitude);
            int longSub = int(winningLongitude) - int(coupons[i].longitude);

            uint distance = sqrt(uint((latSub * latSub) + (longSub * longSub)));

            if(distance < winningRadius) {
                result += coupons[i].value;
            }
        }
        return result;
    }

    function randomInRange(uint min, uint max, uint nonce) internal view returns(uint) {
        uint rand = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, nonce)));
        return uint(rand % (max - min + 1));
    }

    function sqrt(uint x) private pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}