// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CatmullRom {
    struct Vector2D {
        uint256 x;
        uint256 y;
    }

    Vector2D[] private curvePoints;

    constructor(Vector2D[] memory _curvePoints) {
        require(_curvePoints.length >= 4, "At least 4 points are required for Catmull-Rom curve");
        for (uint256 i = 0; i < _curvePoints.length; i++) {
            curvePoints.push(_curvePoints[i]);
        }
    }

    function assetsToShares(uint256 assetAmount) public view returns (uint256) {
        require(assetAmount > 0, "Asset amount must be greater than 0");
        return calculateCurveValue(assetAmount, true);
    }

    function sharesToAssets(uint256 shareAmount) public view returns (uint256) {
        require(shareAmount > 0, "Share amount must be greater than 0");
        return calculateCurveValue(shareAmount, false);
    }

    function calculateCurveValue(uint256 amount, bool isAssetsToShares) private view returns (uint256) {
        uint256 segmentCount = curvePoints.length - 3;
        uint256 segmentSize;

        if (isAssetsToShares) {
            segmentSize = (curvePoints[segmentCount + 2].x - curvePoints[0].x) / segmentCount;
        } else {
            segmentSize = (curvePoints[segmentCount + 2].y - curvePoints[0].y) / segmentCount;
        }

        uint256 segment = amount / segmentSize;
        if (segment >= segmentCount) segment = segmentCount - 1;

        uint256 localAmount = amount - (segment * segmentSize);
        // uint256 t = (localAmount * 1e18) / segmentSize;

        {
            Vector2D memory p0 = curvePoints[segment];
            Vector2D memory p1 = curvePoints[segment + 1];
            Vector2D memory p2 = curvePoints[segment + 2];
            Vector2D memory p3 = curvePoints[segment + 3];

            return calculateQuadraticApproximation(p0, p1, p2, p3, (localAmount * 1e18) / segmentSize, isAssetsToShares);
        }
    }

    function calculateQuadraticApproximation(
        Vector2D memory p0,
        Vector2D memory p1,
        Vector2D memory p2,
        Vector2D memory p3,
        uint256 t,
        bool isAssetsToShares
    ) private pure returns (uint256) {
        uint256 t2 = (t * t) / 1e18;

        if (isAssetsToShares) {
            uint256 a = ((p3.y - p0.y - 3) * (p2.y - p1.y)) / 2;
            uint256 b = p2.y - p0.y - a;
            return ((a * t2) / 1e18) + ((b * t) / 1e18) + p1.y;
        } else {
            uint256 a = ((p3.x - p0.x - 3) * (p2.x - p1.x)) / 2;
            uint256 b = p2.x - p0.x - a;
            return ((a * t2) / 1e18) + ((b * t) / 1e18) + p1.x;
        }
    }

    function getPointOnCurve(uint256 t) private view returns (Vector2D memory) {
        require(t <= 1e18, "t must be between 0 and 1");

        uint256 segmentCount = curvePoints.length - 3;
        uint256 segment = (t * segmentCount) / 1e18;
        uint256 localT = (t * segmentCount) % 1e18;

        {
            Vector2D memory p0 = curvePoints[segment];
            Vector2D memory p1 = curvePoints[segment + 1];
            Vector2D memory p2 = curvePoints[segment + 2];
            Vector2D memory p3 = curvePoints[segment + 3];

            uint256 t2 = (localT * localT) / 1e18;
            uint256 t3 = (t2 * localT) / 1e18;

            uint256 x = catmullRomInterpolation(p0.x, p1.x, p2.x, p3.x, localT, t2, t3);
            uint256 y = catmullRomInterpolation(p0.y, p1.y, p2.y, p3.y, localT, t2, t3);

            return Vector2D(x, y);
        }
    }

    function catmullRomInterpolation(uint256 p0, uint256 p1, uint256 p2, uint256 p3, uint256 t, uint256 t2, uint256 t3)
        private
        pure
        returns (uint256)
    {
        uint256 a = p1 * 2e18;
        uint256 b = ((p2 - p0) * t) / 2;
        uint256 c = ((p0 * 2e18 - p1 * 5e18 + p2 * 4e18 - p3) * t2) / 2;
        uint256 d = ((p1 * 3e18 - p0 - p2 * 3e18 + p3) * t3) / 2;
        return a + b + c + d;
    }
}
