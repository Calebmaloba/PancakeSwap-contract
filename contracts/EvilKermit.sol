// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
    ███████╗██╗   ██╗██╗██╗     ██╗  ██╗███████╗██████╗ ███╗   ███╗██╗████████╗
    ██╔════╝██║   ██║██║██║     ██║ ██╔╝██╔════╝██╔══██╗████╗ ████║██║╚══██╔══╝
    █████╗  ██║   ██║██║██║     █████╔╝ █████╗  ██████╔╝██╔████╔██║██║   ██║   
    ██╔══╝  ╚██╗ ██╔╝██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║   
    ███████╗ ╚████╔╝ ██║███████╗██║  ██╗███████╗██║  ██║██║ ╚═╝ ██║██║   ██║   
    ╚══════╝  ╚═══╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝   ╚═╝   
                                                                            
*/

contract EvilKermit is ERC20 {
    constructor() ERC20("EvilKermit Coin", "EvilKermit") {
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount * 10 ** 18);
    }
}