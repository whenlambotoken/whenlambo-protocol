// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./BEP20.sol";
import "./utils/SafeMath.sol";
import "./access/Ownable.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router.sol";

contract TokenSplitter is Ownable {
    using SafeMath for uint256;

    struct Shareholder {
        address payable account;
        uint256 shares;
    }

    Shareholder[] public shareholders;
    uint256 public totalShares;

    address public immutable TOKEN = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82; // CAKE
    address public immutable BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD

    IUniswapV2Router02 public uniswapV2Router;

    constructor() public {
    	// Mainnet: 0x10ED43C718714eb63d5aA57B78B54704E256024E
    	// Testnet: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1

    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Router = _uniswapV2Router;

        addShareholder(0xE64789Ecb4b13306b6B3DB3C8408f56500a496f7, 15);
        addShareholder(0x2054cec999aceb8684FDe957021Fef44c4D17803, 15);
        addShareholder(0x677cDfA11D3Fb6A41E851Ab31a11e03845bc94Ac, 10);
    }

    receive() external payable {}

    function splitInTOKEN() external {
        require(shareholders.length > 1, '!shareholders');
        uint256 balance = IBEP20(TOKEN).balanceOf(address(this));

        for (uint256 index = 0; index < shareholders.length; index++) {
            if (index == shareholders.length - 1) {
                balance = IBEP20(TOKEN).balanceOf(address(this));
                IBEP20(TOKEN).transfer(shareholders[index].account, balance);
                break;
            }

            uint256 shares = shareholders[index].shares;
            IBEP20(TOKEN).transfer(shareholders[index].account, balance.mul(shares).div(totalShares));
        }
    }

    function splitInBNB() external {
        require(shareholders.length > 1, '!shareholders');

        uint256 balance = IBEP20(TOKEN).balanceOf(address(this));
        swapTokensForBnb(balance);
        uint256 total = address(this).balance;

        for (uint256 index = 0; index < shareholders.length; index++) {
            if (index == shareholders.length - 1) {
                total = address(this).balance;
                shareholders[index].account.transfer(total);
                break;
            }

            uint256 shares = shareholders[index].shares;
            shareholders[index].account.transfer(total.mul(shares).div(totalShares));
        }
    }

    function splitInBUSD() external {
        require(shareholders.length > 1, '!shareholders');

        uint256 balance = IBEP20(TOKEN).balanceOf(address(this));
        swapTokensForBusd(balance);
        uint256 total = IBEP20(BUSD).balanceOf(address(this));

        for (uint256 index = 0; index < shareholders.length; index++) {
            if (index == shareholders.length - 1) {
                total = IBEP20(BUSD).balanceOf(address(this));
                IBEP20(BUSD).transfer(shareholders[index].account, total);
                break;
            }

            uint256 shares = shareholders[index].shares;
            IBEP20(BUSD).transfer(shareholders[index].account, total.mul(shares).div(totalShares));
        }
    }

    /* INTERNAL FUNCTION */

    function swapTokensForBnb(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = TOKEN;
        path[1] = uniswapV2Router.WETH();

        IBEP20(TOKEN).approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForBusd(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> bnb -> busd
        address[] memory path = new address[](3);
        path[0] = TOKEN;
        path[1] = uniswapV2Router.WETH();
        path[2] = BUSD;

        IBEP20(TOKEN).approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BUSD
            path,
            address(this),
            block.timestamp
        );
    }

    /* RESTRICTED FUNCTIONS */

    function addShareholder(address payable account, uint256 shares) public onlyOwner {
        require(account != address(0) && shares > 0, '!invalid');
        shareholders.push(Shareholder(account, shares));
        totalShares = totalShares.add(shares);
    }

    function removeShareholder(uint256 index) external onlyOwner {
        if (index >= shareholders.length) return;

        uint256 shares = shareholders[index].shares;

        for (uint256 i = index; i < shareholders.length - 1; i++){
            shareholders[i] = shareholders[i + 1];
        }

        shareholders.pop();
        totalShares = totalShares.sub(shares);
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(0), '!null');
        require(IBEP20(token).balanceOf(address(this)) >= amount, '!amount');
        IBEP20(token).transfer(owner(), amount);
    }

    function withdrawBNB(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, '!amount');
        payable(owner()).transfer(amount);
    }
}