// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { DataTypes } from "./shared/DataTypes.sol";

interface RegisterDoctorInterface {
    function registerDoctor(string memory name, string memory specialization, string memory licenseId) external;
    function getAllDoctors() external view returns (DataTypes.Doctor[] memory);
    function deleteDoctor(uint256 doctorId) external;
}
