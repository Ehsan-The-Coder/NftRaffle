//SPDX-Licence-Identifier:MIT
pragma solidity ^0.8.20;

//<----------------------------import statements---------------------------->

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// import {console} from "forge-std/Script.sol";

// import "@chainlink/contracts/src/v0.7/dev/VRFConsumerBase.sol";

contract NftRaffle {
    //<----------------------------type declarations---------------------------->
    enum State {
        CREATED,
        OPEN,
        CALCULATING,
        CLOSED
    }
    struct Raffle {
        address creator;
        address nftContract;
        uint256 nftId;
        uint40 price;
        uint40 threshold;
        uint256 start;
        uint256 end;
        address[] participants;
        int256 winnerIndex;
        address withdrawer;
        State state;
    }
    //<----------------------------state variable---------------------------->
    uint16 private MIN_PRICE_IN_DOLLARS = 5;
    uint40 private MAX_PRICE_IN_DOLLARS = 100000000;
    uint16 private MIN_THRESHOLD = 5;
    uint40 private MAX_THRESHOLD = 100;
    uint8 private MIN_START_DAYS = 0;
    uint8 private MAX_START_DAYS = 30;
    uint8 private MIN_END_DAYS = 10;
    uint8 private MAX_END_DAYS = 90;
    ///@dev list of all available tokens which are acceptable for participating in the raffle as currency
    address[] private s_tokens;
    uint256 private s_id = 1;

    mapping(address token => bool existed) private s_tokenExisted;
    mapping(uint256 id => Raffle raffle) private s_raffleId;
    mapping(address creator => uint256[] raffleId) private s_raffleCreator;
    mapping(address participant => uint256[] raffleId)
        private s_raffleParticipant;
    mapping(address winner => uint256[] raffleId) private s_raffleWinner;

    //<----------------------------events------------------------------------>
    //<----------------------------custom errors---------------------------->
    error NftRaffle__OutOfRange(string msgType);
    error NftRaffle__NotExistedOrNotInOpenState();
    error NftRaffle__TokenAddressNotExisted();
    error NftRaffle__ValueMustBeGreaterThanZero();
    //<----------------------------modifiers------------------------------->
    ///@dev we combine priceRange and thresholdRange in single modifier to reduce code and deployment cost but it make the message ambigious and also cost more usage gas
    modifier validateRanges(
        uint40 _price,
        uint40 _threshold,
        uint8 _startInDays,
        uint8 _endInDays
    ) {
        if (_price < MIN_PRICE_IN_DOLLARS || _price > MAX_PRICE_IN_DOLLARS) {
            revert NftRaffle__OutOfRange("price");
        }
        if (_threshold < MIN_THRESHOLD || _threshold > MAX_THRESHOLD) {
            revert NftRaffle__OutOfRange("threshold");
        }
        if (_startInDays < MIN_START_DAYS || _startInDays > MAX_START_DAYS) {
            revert NftRaffle__OutOfRange("startDays");
        }
        if (_endInDays < MIN_END_DAYS || _endInDays > MAX_END_DAYS) {
            revert NftRaffle__OutOfRange("endDays");
        }
        _;
    }

    modifier validateRaffle(uint256 _raffleId) {
        if (s_raffleId[_raffleId].state != State.OPEN) {
            revert NftRaffle__NotExistedOrNotInOpenState();
        }
        _;
    }
    modifier validateToken(address _token) {
        if (s_tokenExisted[_token] == false) {
            revert NftRaffle__TokenAddressNotExisted();
        }
        _;
    }
    modifier aboveZero(uint256 _value) {
        if (_value == 0) {
            revert NftRaffle__ValueMustBeGreaterThanZero();
        }
        _;
    }

    //<----------------------------functions------------------------------->
    //<----------------------------constructor------------------------------>
    ///@dev we not putting too much constrains on constructor
    //becuase deployment as made throgh developer
    //so to keep the code short and efficiant we assume
    //that developer provide appropriate tokens address
    constructor(address[] memory _tokens) {
        for (uint256 index = 0; index < _tokens.length; index++) {
            s_tokenExisted[_tokens[index]] = true;
        }
        s_tokens = _tokens;
    }

    //<----------------------------external functions---------------------------->
    ///@dev price must be in dollar from range to 5 dollar to 1099511627775
    // struct Raffle {creator,nftContract,nftId,price,threshold,start,end,participants,winnerIndex,withdrawer, state}
    function initiateRaffle(
        address _nftContract,
        uint256 _nftId,
        uint40 _price,
        uint40 _threshold,
        uint8 _startInDays,
        uint8 _endInDays
    )
        external
        validateRanges(_price, _threshold, _startInDays, _endInDays)
        returns (uint256)
    {
        // transfer the nft from the raffle creator to this contract
        ///@dev must need a approval from owner
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _nftId);

        uint256 _raffleId = s_id;
        _initiateRaffle(
            address(_nftContract),
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
        return _raffleId;
    }

    function buyRaffleFromTokens(
        uint256 _raffleId,
        address _token,
        uint256 _amount
    )
        external
        view
        validateRaffle(_raffleId)
        validateToken(_token)
        aboveZero(_amount)
    {}

    //<----------------------------public functions---------------------------->
    //<----------------------------external/public view/pure functions---------------------------->
    function getAcceptableToken(uint256 index) external view returns (address) {
        return s_tokens[index];
    }

    function getAcceptableTokens() external view returns (address[] memory) {
        return s_tokens;
    }

    function getMinimumPrice() external view returns (uint16) {
        return MIN_PRICE_IN_DOLLARS;
    }

    function getMaximumPrice() external view returns (uint40) {
        return MAX_PRICE_IN_DOLLARS;
    }

    function getMinimumThreshold() external view returns (uint16) {
        return MIN_THRESHOLD;
    }

    function getMaximumThreshold() external view returns (uint40) {
        return MAX_THRESHOLD;
    }

    function getMinimumStartDays() external view returns (uint8) {
        return MIN_START_DAYS;
    }

    function getMaximumStartDays() external view returns (uint8) {
        return MAX_START_DAYS;
    }

    function getMinimumEndDays() external view returns (uint8) {
        return MIN_END_DAYS;
    }

    function getMaximumEndDays() external view returns (uint8) {
        return MAX_END_DAYS;
    }

    function isTokenExisted(address _token) external view returns (bool) {
        return s_tokenExisted[_token];
    }

    ///@dev return the Raffle
    ///@return the raffleId that is going to be assign to the next Raffle
    function getRaffleId() external view returns (uint256) {
        return s_id;
    }

    function getRaffleById(
        uint256 _raffleId
    ) external view returns (Raffle memory) {
        return s_raffleId[_raffleId];
    }

    //<----------------------------private functions---------------------------->
    function _initiateRaffle(
        address _nftContract,
        uint256 _nftId,
        uint40 _price,
        uint40 _threshold,
        uint8 _startInDays,
        uint8 _endInDays
    ) private {
        uint256 _start = block.timestamp + _startInDays;
        uint256 _end = _start + _endInDays;
        int256 _winnerIndex = -1;
        address[] memory _participants;
        address _withdrawer = address(0);
        State _raffleState = State.CREATED;
        if (_startInDays == 0) {
            _raffleState = State.OPEN;
        }

        s_raffleId[s_id] = Raffle(
            msg.sender,
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _start,
            _end,
            _participants,
            _winnerIndex,
            _withdrawer,
            _raffleState
        );
        s_raffleCreator[msg.sender].push(s_id);
        s_id++;
    }

    //<----------------------------private view/pure functions---------------------------->
}
