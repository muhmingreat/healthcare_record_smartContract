// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import { RegisterPatientInterface } from "./RegisterPatientInterface.sol";
import { RegisterDoctorInterface } from "./RegisterDoctorInterface.sol";
import { MedicalRecordInterface } from "./MedicalRecordInterface.sol";
import { AppointmentInterface } from "./AppointmentInterface.sol";
import { DataTypes } from "./shared/DataTypes.sol";
import { Events } from "./shared/Events.sol";
import { Errors } from "./shared/Errors.sol";

contract HealthcareRecordSystem is
    AccessControl,
    RegisterPatientInterface,
    RegisterDoctorInterface,
    MedicalRecordInterface,
    AppointmentInterface
{
    using DataTypes for *;

    bytes32 public constant DOCTOR_ROLE = keccak256("DOCTOR_ROLE");
    bytes32 public constant PATIENT_ROLE = keccak256("PATIENT_ROLE");

    address public appOwner;
    uint256 public minFee = 0.0001 ether;

    DataTypes.Patient[] public patients;
    DataTypes.Doctor[] public doctors;
    DataTypes.MedicalRecord[] public records;
    DataTypes.Appointment[] public appointments;
    DataTypes.Payment[] public payments;

    mapping(address => uint256[]) public userPayments;
    mapping(address => uint256) public addressToPatientId;
    mapping(address => uint256) public addressToDoctorId;
    mapping(uint256 => mapping(address => bool)) public recordAccess;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        appOwner = msg.sender;
    }

    modifier onlyPatientOwner(uint256 patientId) {
        if (patientId == 0 || patientId > patients.length) revert Errors.InvalidPatientId();
        if (patients[patientId - 1].account != msg.sender) revert Errors.NotPatientOwner();
        _;
    }

    function registerPatient(string memory name, uint256 age, string memory gender) external override {
        if (msg.sender == address(0)) revert Errors.InvalidSender();
        if (addressToPatientId[msg.sender] != 0) revert Errors.AlreadyRegistered();
        uint256 _id = patients.length + 1;

        patients.push(DataTypes.Patient({
            id: _id,
            name: name,
            age: age,
            gender: gender,
            account: msg.sender,
            isDeleted: false
        }));

        addressToPatientId[msg.sender] = _id;
        _grantRole(PATIENT_ROLE, msg.sender);
        emit Events.PatientRegistered(_id, msg.sender);
    }

    function getMyPatientProfile() public view override returns (DataTypes.Patient memory) {
        uint256 id = addressToPatientId[msg.sender];
        if (id == 0) revert Errors.PatientNotFound();
        if (patients[id - 1].isDeleted) revert Errors.DeletedPatient();
        return patients[id - 1];
    }

    function getSinglePatient(uint256 patientId) external view override returns (DataTypes.Patient memory) {
        if (patientId == 0 || patientId > patients.length) revert Errors.InvalidPatientId();
        if (patients[patientId - 1].isDeleted) revert Errors.DeletedPatient();
        return patients[patientId - 1];
    }

    function registerDoctor(string memory name, string memory specialization, string memory licenseId) external override {
        if (msg.sender == address(0)) revert Errors.InvalidSender();
        if (addressToDoctorId[msg.sender] != 0) revert Errors.AlreadyRegistered();
        uint256 _id = doctors.length + 1;

        doctors.push(DataTypes.Doctor({
            id: _id,
            name: name,
            specialization: specialization,
            licenseId: licenseId,
            account: msg.sender,
            isDeleted: false
        }));

        addressToDoctorId[msg.sender] = _id;
        _grantRole(DOCTOR_ROLE, msg.sender);
        emit Events.DoctorRegistered(_id, msg.sender);
    }

    function getAllDoctors() external view override returns (DataTypes.Doctor[] memory) {
        return doctors;
    }

    function addMedicalRecord(
        uint256 patientId,
        string memory ipfsUrl,
        string memory patientName,
        string memory diagnosis
    ) external override onlyRole(PATIENT_ROLE) onlyPatientOwner(patientId) {
        if (patients[patientId - 1].isDeleted) revert Errors.DeletedPatient();
        uint256 id = records.length + 1;
        records.push(DataTypes.MedicalRecord({
            id: id,
            patientId: patientId,
            doctorId: 0,
            ipfsUrl: ipfsUrl,
            patientName: patientName,
            diagnosis: diagnosis,
            prescription: "",
            timestamp: block.timestamp,
            isDeleted: false
        }));
        emit Events.MedicalRecordAdded(id, patientId, 0);
    }

    function prescribeMedicine(uint256 recordId, string memory prescription) external override onlyRole(DOCTOR_ROLE) {
        if (recordId == 0 || recordId > records.length) revert Errors.InvalidRecordId();
        DataTypes.MedicalRecord storage rec = records[recordId - 1];
        if (rec.isDeleted) revert Errors.DeletedRecord();
        rec.prescription = prescription;
        rec.doctorId = addressToDoctorId[msg.sender];
        emit Events.PrescriptionAdded(recordId, prescription);
    }

    function getPatientMedicalRecords(uint256 patientId) external view override returns (DataTypes.MedicalRecord[] memory) {
        if (!canView(patientId, msg.sender)) revert Errors.UnauthorizedAccess();
        uint256 count = 0;
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].patientId == patientId && !records[i].isDeleted) count++;
        }
        DataTypes.MedicalRecord[] memory output = new DataTypes.MedicalRecord[](count);
        uint256 j;
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].patientId == patientId && !records[i].isDeleted) {
                output[j++] = records[i];
            }
        }
        return output;
    }

    function getAllPatientsRecords() external view override onlyRole(DEFAULT_ADMIN_ROLE) returns (DataTypes.Patient[] memory) {
        return patients;
    }

    function deleteMedicalRecord(uint256 recordId) external override {
        if (recordId == 0 || recordId > records.length) revert Errors.InvalidRecordId();
        DataTypes.MedicalRecord memory rec = records[recordId - 1];
        if (rec.patientId == 0 || (patients[rec.patientId - 1].account != msg.sender && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender))) {
            revert Errors.UnauthorizedAccess();
        }
        for (uint256 i = recordId - 1; i < records.length - 1; i++) {
            records[i] = records[i + 1];
        }
        records.pop();
        emit Events.RecordDeleted(recordId);
    }

    function deletePatient(uint256 patientId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (patientId == 0 || patientId > patients.length) revert Errors.InvalidPatientId();
        address patientAddr = patients[patientId - 1].account;
        if (patientAddr == address(0)) revert Errors.AlreadyRegistered();
        delete addressToPatientId[patientAddr];
        for (uint256 i = patientId - 1; i < patients.length - 1; i++) {
            patients[i] = patients[i + 1];
        }
        patients.pop();
        _revokeRole(PATIENT_ROLE, patientAddr);
        emit Events.PatientDeleted(patientId);
    }

    function deleteDoctor(uint256 doctorId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (doctorId == 0 || doctorId > doctors.length) revert Errors.InvalidDoctorId();
        for (uint256 i = doctorId - 1; i < doctors.length - 1; i++) {
            doctors[i] = doctors[i + 1];
        }
        doctors.pop();
        emit Events.DoctorDeleted(doctorId);
    }

    function bookAppointment(address doctorAddress, uint256 timestamp)
        external
        payable
        override
        onlyRole(PATIENT_ROLE)
        returns (uint256)
    {
        if (msg.sender == address(0)) revert Errors.InvalidSender();
        if (doctorAddress == address(0)) revert Errors.AddressZero();
        if (msg.value < minFee) revert Errors.InsufficientFee();
        if (timestamp <= block.timestamp) revert Errors.InvalidTimestamp();

        (uint256 patientId, uint256 doctorId) = _validateBookingParties(doctorAddress);
        uint256 id = appointments.length + 1;
        (uint256 share, uint256 royalty) = _splitAndTransferFee(doctorAddress);

        appointments.push(DataTypes.Appointment({
            id: id,
            patientId: patientId,
            doctorId: doctorId,
            timestamp: timestamp,
            isConfirmed: false,
            isDeleted: false,
            isRejected: false,
            fee: msg.value
        }));

        recordAccess[patientId][doctorAddress] = true;

        payments.push(DataTypes.Payment({
            id: payments.length + 1,
            from: msg.sender,
            to: doctorAddress,
            amount: share,
            royalty: royalty,
            timestamp: block.timestamp,
            purpose: "Appointment Booking"
        }));

        emit Events.AppointmentBooked(id, patientId, doctorId);
        emit Events.PaymentMade(payments.length, msg.sender, doctorAddress, share, royalty, "Appointment Booking");
        return id;
    }

    function deleteAppointment(uint256 appointmentId) external override {
        if (appointmentId == 0 || appointmentId > appointments.length) revert Errors.InvalidAppointmentId();
        DataTypes.Appointment storage a = appointments[appointmentId - 1];
        if (
            patients[a.patientId - 1].account != msg.sender &&
            doctors[a.doctorId - 1].account != msg.sender &&
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) revert Errors.UnauthorizedAccess();
        for (uint256 i = appointmentId - 1; i < appointments.length - 1; i++) {
            appointments[i] = appointments[i + 1];
        }
        appointments.pop();
        emit Events.AppointmentDeleted(appointmentId);
    }

    function canView(uint256 patientId, address viewer) public view returns (bool) {
        if (patientId == 0 || patientId > patients.length || patients[patientId - 1].isDeleted) {
            return false;
        }
        return (
            recordAccess[patientId][viewer] ||
            patients[patientId - 1].account == viewer ||
            hasRole(DEFAULT_ADMIN_ROLE, viewer)
        );
    }

    function _validateBookingParties(address doctorAddress)
        internal
        view
        returns (uint256 patientId, uint256 doctorId)
    {
        doctorId = addressToDoctorId[doctorAddress];
        if (doctorId == 0 || doctors[doctorId - 1].isDeleted) revert Errors.DoctorNotFound();

        patientId = addressToPatientId[msg.sender];
        if (patientId == 0 || patients[patientId - 1].isDeleted) revert Errors.PatientNotFound();
    }

    function _splitAndTransferFee(address doctorAddress) internal returns (uint256 doctorShare, uint256 royalty) {
        royalty = (msg.value * 5) / 100;
        doctorShare = msg.value - royalty;
        if (doctorShare == 0) revert Errors.DoctorShareTooLow();
        if (royalty == 0) revert Errors.RoyaltyTooLow();

        (bool sentDoctor, ) = doctorAddress.call{value: doctorShare}();
        if (!sentDoctor) revert Errors.PaymentToDoctorFailed();

        (bool sentOwner, ) = appOwner.call{value: royalty}();
        if (!sentOwner) revert Errors.PaymentToOwnerFailed();
    }

    receive() external payable {}
}