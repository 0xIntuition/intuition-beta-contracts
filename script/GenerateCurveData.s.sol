// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BaseCurve} from "src/BaseCurve.sol";
import {LinearCurve} from "src/LinearCurve.sol";
import {ProgressiveCurve} from "src/ProgressiveCurve.sol";
import {OffsetProgressiveCurve} from "src/OffsetProgressiveCurve.sol";

contract GenerateCurveData is Script {
    // Number of data points to generate
    uint256 constant POINTS = 100;

    // For storing results
    struct DataPoint {
        uint256 assets;
        uint256 shares;
    }

    function setUp() public {}

    function run() public {
        // Initialize all curves we want to analyze
        BaseCurve[] memory curves = new BaseCurve[](3);
        curves[0] = new LinearCurve("Linear");
        curves[1] = new ProgressiveCurve("Progressive", 2);
        curves[2] = new OffsetProgressiveCurve("Offset", 2, 5e35);

        // Create a metadata file to store file locations
        string memory metadata = '{"files":[';

        // Generate and save data for each curve
        for (uint256 i = 0; i < curves.length; i++) {
            BaseCurve curve = curves[i];
            string memory curveName = toLowerCase(curve.name());
            DataPoint[] memory points = generatePoints(curve);
            string memory json = formatJson(curveName, points);

            // Convert curve name to lowercase for filename
            string memory filename = string.concat("out/", curveName, "_curve.json");

            vm.writeFile(filename, json);

            // Add file info to metadata
            if (i > 0) metadata = string.concat(metadata, ",");
            metadata = string.concat(
                metadata,
                '{"name":"',
                curveName,
                '",',
                '"data":"',
                filename,
                '",',
                '"doc":"docs/book/src/',
                curve.name(),
                "Curve.sol/contract.",
                curve.name(),
                'Curve.html"}'
            );
        }

        // Close the metadata JSON and write it
        metadata = string.concat(metadata, "]}");
        vm.writeFile("out/curve_metadata.json", metadata);
    }

    function generatePoints(BaseCurve curve) internal view returns (DataPoint[] memory) {
        DataPoint[] memory points = new DataPoint[](POINTS);
        uint256 maxAssets = 100 ether; // Use 100 ETH as max for visualization
        uint256 step = maxAssets / POINTS;

        points[0] = DataPoint(0, 0);

        for (uint256 i = 1; i < POINTS; i++) {
            uint256 assets = i * step;
            uint256 shares = curve.previewDeposit(assets, 0, 0);
            points[i] = DataPoint(assets, shares);
        }

        return points;
    }

    function formatJson(string memory name, DataPoint[] memory points) internal pure returns (string memory) {
        string memory json = string.concat('{"name":"', name, '","points":[');

        for (uint256 i = 0; i < points.length; i++) {
            // Convert to ETH units for readability
            string memory point = string.concat(
                '{"assets":', vm.toString(points[i].assets), ',"shares":', vm.toString(points[i].shares), "}"
            );

            if (i < points.length - 1) {
                point = string.concat(point, ",");
            }

            json = string.concat(json, point);
        }

        return string.concat(json, "]}");
    }

    function toLowerCase(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Convert uppercase to lowercase
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}
