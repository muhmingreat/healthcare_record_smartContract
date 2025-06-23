// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { DataTypes } from "./shared/DataTypes.sol";
import { Events } from "./shared/Events.sol";

interface RegisterPatientInterface {
    function registerPatient(string memory name, uint256 age, string memory gender) external;
    function getMyPatientProfile() external view returns (DataTypes.Patient memory);
    function getSinglePatient(uint256 patientId) external view returns (DataTypes.Patient memory);
    function getAllPatientsRecords() external view returns (DataTypes.Patient[] memory);
    // function deletePatient(uint256 patientId) external;
}
