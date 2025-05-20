// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {UD60x18, ud, convert} from "@prb/math/UD60x18.sol";
import {console2 as console} from "forge-std/console2.sol";

contract UD60x18Test is Test {
    function testWrap() public pure {
        console.log("wrap(5).mul(wrap(7)).unwrap()");
        uint256 x = 5;
        uint256 y = 7;
        uint256 z = UD60x18.wrap(x).mul(UD60x18.wrap(y)).unwrap();
        console.log("x = ", x);
        console.log("y = ", y);
        console.log("z = ", z);
        assertNotEq(z, 35);
    }

    function testConvertUnwrap() public pure {
        console.log("convert(5).mul(convert(7)).unwrap()");
        uint256 x = 5;
        uint256 y = 7;
        uint256 z = convert(x).mul(convert(y)).unwrap();
        console.log("x = ", x);
        console.log("y = ", y);
        console.log("z = ", z);
        assertNotEq(z, 35);
    }

    function testConvert() public pure {
        console.log("convert(convert(5).mul(convert(7)))");
        uint256 x = 5;
        uint256 y = 7;
        uint256 z = convert(convert(x).mul(convert(y)));

        console.log("x = ", x);
        console.log("y = ", y);
        console.log("z = ", z);
        assertEq(z, 35);
    }

    function testDecimal() public pure {
        uint256 x = 10;
        uint256 y = 3;
        uint256 z = convert(convert(x).div(convert(y)));
        console.log("convert(convert(10).div(convert(3)))");
        console.log("x = ", x);
        console.log("y = ", y);
        console.log("z = ", z);
        assertEq(z, 3);
    }

    function testE18() public pure {
        uint256 x = 10;
        uint256 y = 0.5e18;
        uint256 z = convert(convert(x).mul(convert(y)));
        console.log("convert(convert(10).mul(convert(0.5e18)))");
        console.log("x = ", x);
        console.log("y = ", y);
        console.log("z = ", z);
        assertNotEq(z, 5);
    }

    function testE18Wrap() public pure {
        uint256 x = 10;
        uint256 y = 0.5e18;
        uint256 z = convert(convert(x).mul(UD60x18.wrap(y)));
        console.log("convert(convert(10).mul(wrap(0.5e18)))");
        console.log("x = ", x);
        console.log("y = ", y);
        console.log("z = ", z);
        assertEq(z, 5);
    }
}
