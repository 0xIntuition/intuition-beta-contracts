// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {UD60x18, ud, convert} from "@prb/math/UD60x18.sol";
import {console2 as console} from "forge-std/console2.sol";


contract UD60x18Test is Test {

    function testWrap() public {
      console.log("wrap(5).mul(wrap(7)).unwrap()");
      uint256 x = 5;
      uint256 y = 7;
      uint256 z = UD60x18.wrap(x).mul(UD60x18.wrap(y)).unwrap();
      console.log("x = ", x);
      console.log("y = ", y);
      console.log("z = ", z);
    }

    function testConvertUnwrap() public {
      console.log("convert(5).mul(convert(7)).unwrap()");
      uint256 x = 5;
      uint256 y = 7;
      uint256 z = convert(x).mul(convert(y)).unwrap();
      console.log("x = ", x);
      console.log("y = ", y);
      console.log("z = ", z);
    }

    function testConvert() public {
      console.log("convert(convert(5).mul(convert(7)))");
      uint256 x = 5;
      uint256 y = 7;
      uint256 z = convert(convert(x).mul(convert(y)));

      console.log("x = ", x);
      console.log("y = ", y);
      console.log("z = ", z);
      assertEq(z, 35);
    }
} 
