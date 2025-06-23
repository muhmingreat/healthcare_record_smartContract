// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    // Access and Authorization
    error UnauthorizedAccess();
    error NotPatientOwner();
    error NotDoctorOwner();
    error InvalidSender();

    // Registration
    error AlreadyRegistered();
    error PatientNotFound();
    error DoctorNotFound();

    // Validation
    error InvalidPatientId();
    error InvalidDoctorId();
    error InvalidRecordId();
    error InvalidAppointmentId();
    error InvalidTimestamp();
    error DeletedPatient();
    error DeletedDoctor();
    error DeletedRecord();

    // Payment and Booking
    error InsufficientFee();
    error DoctorShareTooLow();
    error RoyaltyTooLow();
    error PaymentToDoctorFailed();
    error PaymentToOwnerFailed();

    // Misc
    error AddressZero();
    error SameDayBookingNotAllowed();
}