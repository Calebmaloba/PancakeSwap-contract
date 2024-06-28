// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IPancakeRouter02.sol";

contract EvilKermitStaking is Ownable {
    address public evilKermitContract ; // EvilKermit token contract address
    address public pancakeSwapContract; // pancakeswap router contract address
    // amt of cxses staked by an address
    struct Position {
        uint256 positionId;
        address walletAddress;
        uint256 createdDate;
        uint256 unlockDate;
        uint256 percentInterest;
        uint256 weiStaked;
        uint256 weiInterest;
        bool open;
    }
    uint256 public currentPositionId;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public positionIdsByAddress;
    mapping(uint256 => uint256) public tiers;
    uint256[] public lockPeriods;

    constructor(address initialOwner, address _pancakeSwap, address _evilkermit) Ownable(initialOwner) {
        currentPositionId = 0; // Initialize currentPositionId
        pancakeSwapContract = _pancakeSwap;
        evilKermitContract = _evilkermit;
    }

    // get Amount of EvilKermit token when user send other token
    function getAmountOfEvilKermit(address _tokenAddress, uint256 _amount)
        public
        view
        returns (uint256)
    {
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = evilKermitContract;
        uint256 amoutOut = IPancakeRouter02(pancakeSwapContract).getAmountsOut(
            _amount,
            path
        )[1];
        uint256 amoutMinout = (amoutOut * (1000 - 5)) / 1000; //slipage 0.5%
        return amoutMinout;
    }

    function swapTokenToEvilKermit(address _tokenAddress, uint256 _amount)
        internal
        returns (uint256)
    {
        uint256 allowance = IERC20(_tokenAddress).allowance(
            msg.sender,
            address(this)
        );
        require(allowance >= _amount, "Allowance Error");
        require(
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "dont send token"
        );
        require(
            address(evilKermitContract) != address(0),
            "EvilKermit address is zero"
        );
        if (address(_tokenAddress) == address(evilKermitContract)) {
            return _amount;
        } else {
            uint256[] memory retAmounts = _convertTokenToEvilKermit(
                _amount,
                _tokenAddress
            );
            return retAmounts[1];
        }
    }

    function swapBNBToEvilKermit(uint256 _amount)
        public
        payable
        returns (uint256)
    {
        require(msg.value > 0, "BNB is zero");
        require(_amount == msg.value, "amount must be same with value");
        uint256[] memory retAmounts = _convertBNBToEvilKermit(_amount);
        return retAmounts[1];
    }

    // convert BNB to EvilKermit token using pancake swap router
    function _convertBNBToEvilKermit(uint256 _amount)
        public
        payable
        returns (uint256[] memory)
    {
        require(evilKermitContract != address(0), "EvilKermitContract is zero");
        require(
            address(pancakeSwapContract) != address(0),
            "Invalid Pancakeswap"
        );
        address[] memory path = new address[](2);
        path[0] = IPancakeRouter02(pancakeSwapContract).WETH();
        path[1] = address(evilKermitContract);
        require(
            IERC20(path[0]).approve(address(pancakeSwapContract), _amount),
            "approve failed"
        );
        uint256 amoutOut = IPancakeRouter02(pancakeSwapContract).getAmountsOut(
            _amount,
            path
        )[1];
        uint256 amoutMinout = (amoutOut * (1000 - 5)) / 1000; //slipage 0.5%
        uint256[] memory retAmounts = IPancakeRouter02(pancakeSwapContract)
            .swapExactETHForTokens{value: msg.value}(
            amoutMinout,
            path,
            address(this),
            block.timestamp
        );
        return retAmounts;
    }

    // convert token to EvilKermit token using pancake swap router
    function _convertTokenToEvilKermit(uint256 _amount, address _tokenAddress)
        internal
        returns (uint256[] memory)
    {
        require(evilKermitContract != address(0), "EvilKermitContract is zero");
        require(
            address(pancakeSwapContract) != address(0),
            "Invalid Pancakeswap"
        );
        address[] memory path = new address[](2);
        path[0] = address(_tokenAddress);
        path[1] = address(evilKermitContract);
        require(
            IERC20(path[0]).approve(address(pancakeSwapContract), _amount),
            "approve failed"
        );
        uint256 amoutOut = IPancakeRouter02(pancakeSwapContract).getAmountsOut(
            _amount,
            path
        )[1];
        uint256 amoutMinout = (amoutOut * (1000 - 5)) / 1000; //slipage 0.5%
        uint256[] memory retAmounts = IPancakeRouter02(pancakeSwapContract)
            .swapExactTokensForTokens(
                _amount,
                amoutMinout,
                path,
                address(this),
                block.timestamp
            );
        return retAmounts;
    }

    // num of days staked for
    function stakeBNB(uint256 numDays) external payable {
        require(tiers[numDays] > 0, "Mapping not found");
        uint256 amount = swapBNBToEvilKermit(msg.value);
        positions[currentPositionId] = Position(
            currentPositionId,
            msg.sender,
            block.timestamp,
            block.timestamp + (numDays * 15180),
            tiers[numDays],
            amount,
            calculateInterest(tiers[numDays], amount),
            true
        );
        positionIdsByAddress[msg.sender].push(currentPositionId);
        currentPositionId++;
    }

    function stakeToken(
        address _tokenAddress,
        uint256 _amount,
        uint256 numDays
    ) external payable {
        require(tiers[numDays] > 0, "Mapping not found");
        uint256 amount = swapTokenToEvilKermit(_tokenAddress, _amount);
        uint256 date = numDays * 1 seconds;
        positions[currentPositionId] = Position(
            currentPositionId,
            msg.sender,
            block.timestamp,
            block.timestamp + date,
            tiers[numDays],
            amount,
            calculateInterest(tiers[numDays], amount),
            true
        );
        positionIdsByAddress[msg.sender].push(currentPositionId);
        currentPositionId++;
    }

    function calculateInterest(uint256 basisPoints, uint256 weiAmount)
        private
        pure
        returns (uint256)
    {
        return (basisPoints * weiAmount) / 10000;
    }

    function modifyLockPeriods(uint256 numDays, uint256 basisPoints)
        external
        onlyOwner
    {
        tiers[numDays] = basisPoints;
        lockPeriods.push(numDays);
    }

    function getLockPeriods() external view returns (uint256[] memory) {
        return lockPeriods;
    }

    function getInterestRate(uint256 numDays) external view returns (uint256) {
        return tiers[numDays];
    }

    function getPositionById(uint256 positionId)
        external
        view
        returns (Position memory)
    {
        return positions[positionId];
    }

    function getPositionIdsForAddress(address walletAddress)
        external
        view
        returns (uint256[] memory)
    {
        return positionIdsByAddress[walletAddress];
    }

    function closePosition(uint256 positionId) external {
        require(
            positions[positionId].walletAddress == msg.sender,
            "Only position creator can modify the position"
        );
        require(positions[positionId].open == true, "Position is closed");
        require(
            address(evilKermitContract) != address(0),
            "Invalid EvilKermit token"
        );
        require(
            block.timestamp >= positions[positionId].unlockDate,
            "Not EndDay"
        );
        positions[positionId].open = false;
        uint256 amount = positions[positionId].weiStaked +
            positions[positionId].weiInterest;
        require(
            IERC20(evilKermitContract).approve(address(this), amount),
            "Dont approve"
        );
        require(
            IERC20(evilKermitContract).transferFrom(
                address(this),
                msg.sender,
                amount
            ),
            "Dont send evilKermit"
        );
    }

    function setEvilKermitContract(address _tokenAddress) public onlyOwner {
        require(address(_tokenAddress) != address(0), "Invalid address");
        evilKermitContract = _tokenAddress;
    }

    function setPancakeRouterContract(address _pancake) public onlyOwner {
        require(address(_pancake) != address(0), "Invalid address");
        pancakeSwapContract = _pancake;
    }
}
