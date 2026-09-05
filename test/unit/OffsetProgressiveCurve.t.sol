// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {UD60x18, convert} from "@prb/math/UD60x18.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";
import {ProgressiveCurve} from "src/ProgressiveCurve.sol";

/// @notice Pins the `previewMint` <-> `previewDeposit`/`previewRedeem` math for both curve
/// variants directly against the docstring formulas, independent of the contracts' own
/// internal helpers, so the same class of bug can't hide behind a shared implementation detail.
contract OffsetProgressiveCurvePreviewMintTest is Test {
    uint256 constant SLOPE = 0.0025e18;
    uint256 constant OFFSET = 1e18;

    OffsetProgressiveCurve offsetCurve;
    ProgressiveCurve plainCurve;

    function setUp() public {
        offsetCurve = new OffsetProgressiveCurve("Offset Progressive Curve", SLOPE, OFFSET);
        plainCurve = new ProgressiveCurve("Progressive Curve", SLOPE);
    }

    /// @dev Docstring formula: assets = ((s + n + o)^2 - (s + o)^2) * m/2
    function _expectedOffsetMintAssets(uint256 totalShares, uint256 shares) internal pure returns (uint256) {
        UD60x18 halfSlope = UD60x18.wrap(SLOPE / 2);
        UD60x18 senior = convert(totalShares + shares).add(UD60x18.wrap(OFFSET));
        UD60x18 junior = convert(totalShares).add(UD60x18.wrap(OFFSET));
        return convert(senior.powu(2).sub(junior.powu(2)).mul(halfSlope));
    }

    function testPreviewMintMatchesDocstringFormula() public view {
        uint256 totalShares = 10e18;
        uint256 shares = 5e18;

        uint256 expected = _expectedOffsetMintAssets(totalShares, shares);
        uint256 actual = offsetCurve.previewMint(shares, totalShares, 0);

        assertEq(actual, expected, "previewMint must match ((s+n+o)^2 - (s+o)^2) * m/2");
    }

    function testPreviewMintRoundTripsWithPreviewDeposit() public view {
        uint256 totalShares = 25e18;
        uint256 shares = 3e18;

        uint256 assetsRequired = offsetCurve.previewMint(shares, totalShares, 0);
        uint256 sharesFromDeposit = offsetCurve.previewDeposit(assetsRequired, 0, totalShares);

        assertApproxEqAbs(sharesFromDeposit, shares, 1, "depositing previewMint's assets must yield ~shares back");
    }

    function testPreviewMintRoundTripsWithPreviewRedeem() public view {
        uint256 totalShares = 25e18;
        uint256 shares = 3e18;

        uint256 assetsRequired = offsetCurve.previewMint(shares, totalShares, 0);
        uint256 assetsFromRedeem = offsetCurve.previewRedeem(shares, totalShares + shares, 0);

        assertEq(assetsFromRedeem, assetsRequired, "minting then redeeming the same shares must be symmetric");
    }

    /// @dev Sibling guard: ProgressiveCurve has no OFFSET term, so it can't have this bug.
    /// Pinned here so nobody "fixes" the wrong file later.
    function testSiblingProgressiveCurvePreviewMintUnaffected() public view {
        uint256 totalShares = 10e18;
        uint256 shares = 5e18;

        UD60x18 halfSlope = UD60x18.wrap(SLOPE / 2);
        uint256 expected =
            convert(convert(totalShares + shares).powu(2).sub(convert(totalShares).powu(2)).mul(halfSlope));

        assertEq(plainCurve.previewMint(shares, totalShares, 0), expected);
    }

    function testFuzzPreviewMintMatchesDocstringFormula(uint256 totalShares, uint256 shares) public view {
        totalShares = bound(totalShares, 0, 1_000_000e18);
        shares = bound(shares, 1, 1_000_000e18);

        uint256 expected = _expectedOffsetMintAssets(totalShares, shares);
        uint256 actual = offsetCurve.previewMint(shares, totalShares, 0);

        assertEq(actual, expected);
    }
}
