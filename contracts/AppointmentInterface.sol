// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { DataTypes } from "./shared/DataTypes.sol";

interface AppointmentInterface {
    function bookAppointment(address doctorAddress, uint256 timestamp) external payable returns (uint256);
    function deleteAppointment(uint256 appointmentId) external;
}
