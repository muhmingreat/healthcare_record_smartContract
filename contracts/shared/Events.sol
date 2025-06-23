// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Events {
    event PatientRegistered(uint256 indexed id, address indexed account);
    event DoctorRegistered(uint256 indexed id, address indexed account);
    event MedicalRecordAdded(uint256 indexed id, uint256 indexed patientId, uint256 indexed doctorId);
    event AppointmentBooked(uint256 indexed id, uint256 indexed patientId, uint256 indexed doctorId);
    event AppointmentRejected(uint256 indexed id, uint256 indexed patientId, uint256 indexed doctorId);
    event AccessGranted(uint256 indexed patientId, address indexed grantee);
    event AccessRevoked(uint256 indexed patientId, address indexed grantee);
    event PaymentMade(uint256 indexed id, address indexed from, address indexed to, uint256 amount, uint256 royalty, string purpose);
    event PatientDeleted(uint256 indexed patientId);
    event DoctorDeleted(uint256 indexed doctorId);
    event RecordDeleted(uint256 indexed recordId);
    event AppointmentDeleted(uint256 indexed appointmentId);
    event PrescriptionAdded(uint256 indexed recordId, string prescription);
}
