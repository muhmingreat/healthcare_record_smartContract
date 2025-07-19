// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { DataTypes } from "./shared/DataTypes.sol";

interface RegisterDoctorInterface {
    function registerDoctor(string memory name, string memory specialization, 
    string memory licenseId, string memory biography,string memory avatar) external;
    function getSingleDoctor(uint256 doctorId) external view returns (DataTypes.Doctor memory);
    function getDoctorProfile() external view returns (DataTypes.Doctor memory);
    function getMedicalRecordsByDoctor(uint256 doctorId) external view returns (DataTypes.MedicalRecord[] memory);
    function getAllDoctors() external view returns (DataTypes.Doctor[] memory);
    function deleteDoctor(uint256 doctorId) external;
}
