//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

///@dev source(our build) imports
import {NftRaffle} from "../../src/NftRaffle.sol";
///@dev deployments
import {DeployNftRaffle} from "../../script/deploy/DeployNftRaffle.s.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
///@dev foundry imports
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
///@dev openzepplin imports
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Mock} from "../mock/ERC721Mock.sol";

///@dev chainlink imports

contract NftRaffleTest is Test, Script {
    //NOTE we use e and a prefix many time this
    ///@dev e=expect and a=actual

    //<-----------------------------variable--------------------------->
    ///@dev source variables
    enum State {
        CREATED,
        OPEN,
        CALCULATING,
        CLOSED
    }
    uint16 MIN_PRICE_IN_DOLLARS = 5;
    uint40 private MAX_PRICE_IN_DOLLARS = 100000000;
    uint16 private MIN_THRESHOLD = 5;
    uint40 private MAX_THRESHOLD = 100;
    uint8 private MIN_START_DAYS = 0;
    uint8 private MAX_START_DAYS = 30;
    uint8 private MIN_END_DAYS = 10;
    uint8 private MAX_END_DAYS = 90;
    address[] tokens;

    ///@dev TEST Variable
    NftRaffle nftRaffle;
    HelperConfig helperConfig;
    ERC721Mock erc721Mock;
    ERC20Mock erc20Mock;

    address[10] users = [
        address(1),
        address(2),
        address(3),
        address(4),
        address(5),
        address(6),
        address(7),
        address(8),
        address(9),
        address(10)
    ];
    //<-----------------------------event--------------------------->

    //<---------------------------------------modifier------------------------------------------>

    modifier skipForkChains() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
    modifier skipLocalChains() {
        if (block.chainid == 31337) {
            return;
        }
        _;
    }

    //<---------------------------------------setUp------------------------------------------>
    function setUp() external {
        DeployNftRaffle deployNftRaffle = new DeployNftRaffle();
        (nftRaffle, helperConfig, tokens) = deployNftRaffle.run();
        erc721Mock = new ERC721Mock();
    }

    //<---------------------------------------helper functions------------------------------------------>
    function _isContract(address _address) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_address)
        }
        return (size > 0);
    }

    function initiateRaffle(uint8 daysToStart) private returns (uint256) {
        //Arrange
        address user = users[0];

        NftRaffle.Raffle memory _eRaffle;
        NftRaffle.Raffle memory _aRaffle;
        uint256 _eRaffleId;
        uint256 _aRaffleId;
        uint8 zeroDaysToStart = 0;

        _eRaffleId = nftRaffle.getRaffleId();
        _eRaffle.creator = user;
        _eRaffle.nftContract = address(erc721Mock);
        _eRaffle.nftId = 0;
        _eRaffle.price = MIN_PRICE_IN_DOLLARS;
        _eRaffle.threshold = MIN_THRESHOLD;
        _eRaffle.start = daysToStart + block.timestamp;
        _eRaffle.end = MIN_END_DAYS + _eRaffle.start;
        _eRaffle.winnerIndex = -1;
        _eRaffle.withdrawer = address(0);
        _eRaffle.state = NftRaffle.State.CREATED;
        if (_eRaffle.start == zeroDaysToStart + block.timestamp) {
            //this means start imidiate with zero delay
            _eRaffle.state = NftRaffle.State.OPEN;
        }

        //Act
        vm.startPrank(_eRaffle.creator);
        erc721Mock.safeMint(_eRaffle.creator);
        erc721Mock.approve(address(nftRaffle), _eRaffle.nftId);
        _aRaffleId = nftRaffle.initiateRaffle(
            _eRaffle.nftContract,
            _eRaffle.nftId,
            _eRaffle.price,
            _eRaffle.threshold,
            daysToStart,
            MIN_END_DAYS
        );
        vm.stopPrank();

        _aRaffle = nftRaffle.getRaffleById(_aRaffleId);

        //Assert

        assert(_eRaffleId == _aRaffleId);
        assert(_eRaffle.creator == _aRaffle.creator);
        assert(_eRaffle.nftContract == _aRaffle.nftContract);
        assert(_eRaffle.nftId == _aRaffle.nftId);
        assert(_eRaffle.price == _aRaffle.price);
        assert(_eRaffle.threshold == _aRaffle.threshold);
        assert(_eRaffle.start == _aRaffle.start);
        assert(_eRaffle.end == _aRaffle.end);
        assert(_eRaffle.participants.length == _aRaffle.participants.length);
        assert(_eRaffle.winnerIndex == _aRaffle.winnerIndex);
        assert(_eRaffle.withdrawer == _aRaffle.withdrawer);
        assert(_eRaffle.state == _aRaffle.state);

        return _aRaffleId;
    }

    //<---------------------------------------test------------------------------------------>
    ////////////////////////////
    ///////Constructor/////////
    //////////////////////////
    function testConstructorTokensAddressIsSetProperly() external view {
        ///@dev we distributue this test to pass on below coniditions
        //1- token address length should be greater than 0
        //2- set token and get token match
        //3- address of the token should be contract
        //4- also tested the getAcceptableTokens() & getAcceptableToken(index)
        //3- test the isTokenExisted(token)

        address[] memory _tokens = nftRaffle.getAcceptableTokens();

        assert(_tokens.length > 0);
        assert(_tokens.length == tokens.length);
        for (uint256 index = 0; index < _tokens.length; index++) {
            assert(_tokens[index] == tokens[index]);
            assert(_tokens[index] == nftRaffle.getAcceptableToken(index));
            assert(true == nftRaffle.isTokenExisted(_tokens[index]));
            assert(_isContract(_tokens[index]));
        }
    }

    ////////////////////////////
    ///////Constant////////////
    //////////////////////////
    function testConstant() external view {
        assert(MIN_PRICE_IN_DOLLARS == nftRaffle.getMinimumPrice());
        assert(MAX_PRICE_IN_DOLLARS == nftRaffle.getMaximumPrice());
        assert(MIN_THRESHOLD == nftRaffle.getMinimumThreshold());
        assert(MAX_THRESHOLD == nftRaffle.getMaximumThreshold());
        assert(MIN_START_DAYS == nftRaffle.getMinimumStartDays());
        assert(MAX_START_DAYS == nftRaffle.getMaximumStartDays());
        assert(MIN_END_DAYS == nftRaffle.getMinimumEndDays());
        assert(MAX_END_DAYS == nftRaffle.getMaximumEndDays());
    }

    ////////////////////////////////
    ///////initiateRaffle//////////
    //////////////////////////////
    function testInitiateRaffleShouldRevertIfPriceIsOutOfRange() external {
        //expected to revert if
        // _price < MIN_PRICE_IN_DOLLARS || _price > MAX_PRICE_IN_DOLLARS

        //Arrange
        address _nftContract = tokens[0];
        uint256 _nftId = 0;
        uint40 _threshold = MIN_THRESHOLD;
        uint8 _startInDays = MIN_START_DAYS;
        uint8 _endInDays = MIN_END_DAYS;
        uint40 _price = MIN_PRICE_IN_DOLLARS - 1;

        //Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                NftRaffle.NftRaffle__OutOfRange.selector,
                "price"
            )
        );
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );

        //Arrange
        _price = MAX_PRICE_IN_DOLLARS + 1;
        //Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                NftRaffle.NftRaffle__OutOfRange.selector,
                "price"
            )
        );
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
    }

    function testInitiateRaffleShouldRevertIfThresholdIsOutOfRange() external {
        //expected to revert if
        // _threshold < MIN_THRESHOLD || _threshold > MAX_THRESHOLD

        //Arrange
        address _nftContract = tokens[0];
        uint256 _nftId = 0;
        uint40 _price = MIN_PRICE_IN_DOLLARS;
        uint8 _startInDays = MIN_START_DAYS;
        uint8 _endInDays = MIN_END_DAYS;
        uint40 _threshold = MIN_THRESHOLD - 1;

        //Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                NftRaffle.NftRaffle__OutOfRange.selector,
                "threshold"
            )
        );
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );

        //Arrange
        _threshold = MAX_THRESHOLD + 1;
        //Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                NftRaffle.NftRaffle__OutOfRange.selector,
                "threshold"
            )
        );
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
    }

    function testInitiateRaffleShouldRevertIfStartDaysIsOutOfRange() external {
        //expected to revert if
        // _startInDays < MIN_START_DAYS || _startInDays > MAX_START_DAYS
        //don't need to test for minimum start days
        //as they are set to zero and if below given it will automatically revert due to uint underflow

        //Arrange
        address _nftContract = tokens[0];
        uint256 _nftId = 0;
        uint40 _price = MIN_PRICE_IN_DOLLARS;
        uint40 _threshold = MIN_THRESHOLD;
        uint8 _endInDays = MIN_END_DAYS;
        uint8 _startInDays = MAX_START_DAYS + 1;
        //Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                NftRaffle.NftRaffle__OutOfRange.selector,
                "startDays"
            )
        );
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
    }

    function testInitiateRaffleShouldRevertIfEndDaysIsOutOfRange() external {
        //expected to revert if
        // _endInDays < MIN_END_DAYS || _endInDays > MAX_END_DAYS

        //Arrange
        address _nftContract = tokens[0];
        uint256 _nftId = 0;
        uint40 _price = MIN_PRICE_IN_DOLLARS;
        uint40 _threshold = MIN_THRESHOLD;
        uint8 _startInDays = MIN_START_DAYS;
        uint8 _endInDays = MIN_END_DAYS - 1;

        //Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                NftRaffle.NftRaffle__OutOfRange.selector,
                "endDays"
            )
        );
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );

        //Arrange
        _endInDays = MAX_END_DAYS + 1;
        //Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                NftRaffle.NftRaffle__OutOfRange.selector,
                "endDays"
            )
        );
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
    }

    function testInitiateRaffleShouldRevertIfTransferFromFailed() external {
        //1- revert if zero nft contract address or id
        //2- revert if not proper nft contract address or id
        //3- revert if not the owner
        //4- revert if not approved

        //1- revert if zero nft contract address or id
        //Arrange
        uint40 _price = MIN_PRICE_IN_DOLLARS;
        uint40 _threshold = MIN_THRESHOLD;
        uint8 _startInDays = MIN_START_DAYS;
        uint8 _endInDays = MIN_END_DAYS;
        address user = users[0];
        address _nftContract = address(0);
        uint256 _nftId = 0;

        vm.startPrank(user);
        //Assert
        vm.expectRevert();
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
        vm.stopPrank();

        //2- revert if not proper nft contract address or id
        //Arrange
        _nftContract = tokens[0];
        _nftId = 1;
        vm.startPrank(user);
        //Assert
        vm.expectRevert();
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
        vm.stopPrank();

        //3- revert if not the owner
        //Arrange
        _nftContract = address(erc721Mock);
        erc721Mock.safeMint(users[1]);
        _nftId = 0;
        vm.startPrank(user);
        //Assert
        vm.expectRevert();
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
        vm.stopPrank();

        //3- revert if not the owner
        //Arrange
        _nftContract = address(erc721Mock);
        _nftId = 0;
        vm.startPrank(user);
        //Assert
        vm.expectRevert();
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
        vm.stopPrank();

        //4- revert if not approved
        //Arrange
        _nftContract = address(erc721Mock);
        erc721Mock.safeMint(user);
        _nftId = 1; //because 0 is alread minted to the address(this)
        vm.startPrank(user);
        //Assert
        vm.expectRevert();
        //Act
        nftRaffle.initiateRaffle(
            _nftContract,
            _nftId,
            _price,
            _threshold,
            _startInDays,
            _endInDays
        );
        vm.stopPrank();
    }

    function testInitiateRaffleWithZeroDelayToStart() external {
        uint8 daysToStart = 0;
        initiateRaffle(daysToStart);
    }

    function testInitiateRaffleWithDelayToStart() external {
        uint8 daysToStart = 30;
        initiateRaffle(daysToStart);
    }

    ///////////////////////////////////////
    /////////buyRaffleFromTokens//////////
    /////////////////////////////////////

    function testBuyRaffleFromTokensRevertIfRaffleIdNotExisted(
        uint256 _raffleId
    ) external {
        //Arrange
        address _token = address(erc20Mock);
        uint256 _amount = 1000;

        //Assert
        vm.expectRevert(
            NftRaffle.NftRaffle__NotExistedOrNotInOpenState.selector
        );

        //Act
        nftRaffle.buyRaffleFromTokens(_raffleId, _token, _amount);
    }

    function testBuyRaffleFromTokensRevertIfTokenAddressNotExisted(
        address _token
    ) external {
        //Arrange
        if (nftRaffle.isTokenExisted(_token)) {
            return; //if buy chance match with the address of token
        }

        uint8 numberOfDaysToStart = MIN_START_DAYS;
        uint256 _raffleId = initiateRaffle(numberOfDaysToStart);
        uint256 _amount = 1000;

        //Assert
        vm.expectRevert(NftRaffle.NftRaffle__TokenAddressNotExisted.selector);

        //Act
        nftRaffle.buyRaffleFromTokens(_raffleId, _token, _amount);
    }

    function testBuyRaffleFromTokensRevertIfAmountIsZero() external {
        //Arrange
        uint8 zeroIndex = 0;
        address _token = nftRaffle.getAcceptableToken(zeroIndex);
        uint8 numberOfDaysToStart = MIN_START_DAYS;
        uint256 _raffleId = initiateRaffle(numberOfDaysToStart);
        uint256 _amount = 0;

        //Assert
        vm.expectRevert(
            NftRaffle.NftRaffle__ValueMustBeGreaterThanZero.selector
        );

        //Act
        nftRaffle.buyRaffleFromTokens(_raffleId, _token, _amount);
    }
}
