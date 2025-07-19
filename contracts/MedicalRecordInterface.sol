// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { DataTypes } from "./shared/DataTypes.sol";

interface MedicalRecordInterface {
    function addMedicalRecord(uint256 patientId, string memory ipfsUrl, string memory patientName, string memory diagnosis) external;
    function prescribeMedicine(uint256 recordId, string memory prescription) external;
    function getPatientMedicalRecords(uint256 patientId) external view returns (DataTypes.MedicalRecord[] memory);
    
    function deleteMedicalRecord(uint256 recordId) external;
}
