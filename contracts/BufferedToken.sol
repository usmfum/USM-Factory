pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./WadMath.sol";
import "./oracles/IOracle.sol";

/**
 * @title Buffered Token
 * @author Alex Roan (@alexroan)
 * @notice This contract represents a token which accepts ETH as collateral to mint and burn ERC20 tokens.
 * It's functions abstract all oracle, conversion, debt ratio and ETH buffer calculations, so that
 * inheriting contracts can focus on their minting and burning algorithms.
 */
contract BufferedToken is ERC20 {
    using SafeMath for uint;
    using WadMath for uint;

    uint public constant WAD = 10 ** 18;

    uint public ethPool;        //default 0
    address public oracle;

    constructor(address _oracle, string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        oracle = _oracle;
    }

    /**
     * @notice Mint USM from Eth. Inheriting contract must handle the Ether transfers.
     */
    function _mint(uint ethAmount) internal returns (uint) {
        uint usmAmount = _ethToUsm(ethAmount);
        ethPool = ethPool.add(ethAmount);
        super._mint(msg.sender, usmAmount);
        return usmAmount;
    }

    /**
     * @notice Burn USM for Eth. Inheriting contract must handle the Ether transfers.
     */
    function _burn(uint usmAmount) internal returns (uint) {
        uint ethAmount = _usmToEth(usmAmount);
        ethPool = ethPool.sub(ethAmount);
        super._burn(msg.sender, usmAmount);
        return ethAmount;
    }

    /**
     * @notice Calculate the amount of ETH in the buffer
     *
     * @return ETH buffer
     */
    function ethBuffer() public view returns (int) {
        int buffer = int(ethPool) - int(_usmToEth(totalSupply()));
        require(buffer <= int(ethPool), "Underflow error");
        return buffer;
    }

    /**
     * @notice Calculate debt ratio of the current Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio.
     */
    function debtRatio() public view returns (uint) {
        if (ethPool == 0) {
            return 0;
        }
        return totalSupply().wadDiv(_ethToUsm(ethPool));
    }

    /**
     * @notice Convert ETH amount to USM using the latest price of USM
     * in ETH.
     *
     * @param _ethAmount The amount of ETH to convert.
     * @return The amount of USM.
     */
    function _ethToUsm(uint _ethAmount) internal view returns (uint) {
        if (_ethAmount == 0) {
            return 0;
        }
        return _oraclePrice().wadMul(_ethAmount);
    }

    /**
     * @notice Convert USM amount to ETH using the latest price of USM
     * in ETH.
     *
     * @param _usmAmount The amount of USM to convert.
     * @return The amount of ETH.
     */
    function _usmToEth(uint _usmAmount) internal view returns (uint) {
        if (_usmAmount == 0) {
            return 0;
        }
        return _usmAmount.wadDiv(_oraclePrice());
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     *
     * @return price
     */
    function _oraclePrice() internal view returns (uint) {
        // Needs a convertDecimal(IOracle(oracle).decimalShift(), UNIT) function.
        return IOracle(oracle).latestPrice().mul(WAD).div(10 ** IOracle(oracle).decimalShift());
    }
}