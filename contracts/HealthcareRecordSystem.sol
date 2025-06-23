//  SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import { RegisterPatientInterface } from "./RegisterPatientInterface.sol";
import { RegisterDoctorInterface } from "./RegisterDoctorInterface.sol";
import { MedicalRecordInterface } from "./MedicalRecordInterface.sol";
import { AppointmentInterface } from "./AppointmentInterface.sol";
import { DataTypes } from "./shared/DataTypes.sol";
import { Events } from "./shared/Events.sol";

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
    mapping(address => uint256) public patientIds;
    mapping(address => uint256) public doctorIds;
    mapping(uint256 => mapping(address => bool)) public recordAccess;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        appOwner = msg.sender;
    }

    modifier onlyPatientOwner(uint256 patientId) {
        require(patientId > 0 && patientId <= patients.length, "Invalid patient ID");
        require(patients[patientId - 1].account == msg.sender, "Not patient owner");
        _;
    }

    function registerPatient(string memory name, uint256 age, string memory gender) external override {
        require(patientIds[msg.sender] == 0, "Already registered");
        uint256 _id = patients.length + 1;

        patients.push(DataTypes.Patient({
            id: _id,
            name: name,
            age: age,
            gender: gender,
            account: msg.sender,
            isDeleted: false
        }));

        patientIds[msg.sender] = _id;
        _grantRole(PATIENT_ROLE, msg.sender);
        emit Events.PatientRegistered(_id, msg.sender);
    }

    function getMyPatientProfile() public view override returns (DataTypes.Patient memory) {
        uint256 id = patientIds[msg.sender];
        require(id > 0, "No Patient Found");
        require(!patients[id - 1].isDeleted, "Deleted");
        return patients[id - 1];
    }

    function getSinglePatient(uint256 patientId) external view override returns (DataTypes.Patient memory) {
        require(patientId > 0 && patientId <= patients.length, "Invalid patient ID");
        require(!patients[patientId - 1].isDeleted, "Patient deleted");
        return patients[patientId - 1];
    }

    function registerDoctor(string memory name, string memory specialization, string memory licenseId) external override {
        require(doctorIds[msg.sender] == 0, "Already registered");
        uint256 _id = doctors.length + 1;

        doctors.push(DataTypes.Doctor({
            id: _id,
            name: name,
            specialization: specialization,
            licenseId: licenseId,
            account: msg.sender,
            isDeleted: false
        }));

        doctorIds[msg.sender] = _id;
        _grantRole(DOCTOR_ROLE, msg.sender);
        emit Events.DoctorRegistered(_id, msg.sender);
    }

    function getAllDoctors() external view override returns (DataTypes.Doctor[] memory) {
        return doctors;
    }

    function addMedicalRecord(uint256 patientId, string memory ipfsUrl, string memory patientName, string memory diagnosis) external override onlyRole(PATIENT_ROLE) onlyPatientOwner(patientId) {
        require(!patients[patientId - 1].isDeleted, "Deleted");
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
        require(recordId > 0 && recordId <= records.length, "Invalid");
        DataTypes.MedicalRecord storage rec = records[recordId - 1];
        require(!rec.isDeleted, "Deleted");
        rec.prescription = prescription;
        rec.doctorId = doctorIds[msg.sender];
        emit Events.PrescriptionAdded(recordId, prescription);
    }

    function getPatientMedicalRecords(uint256 patientId) external view override returns (DataTypes.MedicalRecord[] memory) {
        require(canView(patientId, msg.sender), "Unauthorized");
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
        require(recordId > 0 && recordId <= records.length, "Invalid");
        DataTypes.MedicalRecord storage rec = records[recordId - 1];
        require(rec.patientId > 0 && patients[rec.patientId - 1].account == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorized");
        rec.isDeleted = true;
        emit Events.RecordDeleted(recordId);
    }
    // function deletePatient(uint256 patientId) external onlyRole(DEFAULT_ADMIN_ROLE) {
    // require(patientId > 0 && patientId <= patients.length, "Invalid patient ID");
    // patients[patientId - 1].isDeleted = true;
    // emit Events.PatientDeleted(patientId); 
    // }
    function deletePatient(uint256 patientId) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(patientId > 0 && patientId <= patients.length, "Invalid patient ID");

    address patientAddr = patients[patientId - 1].account;
    require(patientAddr != address(0), "Already deleted");

    delete patientIds[patientAddr];

    
    delete patients[patientId - 1];


    _revokeRole(PATIENT_ROLE, patientAddr);

    emit Events.PatientDeleted(patientId);
}


    function deleteDoctor(uint256 doctorId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    require(doctorId > 0 && doctorId <= doctors.length, "Invalid doctor");
    doctors[doctorId - 1].isDeleted = true;

    emit Events.DoctorDeleted(doctorId); 
}
    function bookAppointment(address doctorAddress, uint256 timestamp) external payable override onlyRole(PATIENT_ROLE) returns (uint256) {
        require(msg.value >= minFee, "Low Fee");
        require(timestamp > block.timestamp, "Invalid time");
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
        require(appointmentId > 0 && appointmentId <= appointments.length, "Invalid");
        DataTypes.Appointment storage a = appointments[appointmentId - 1];
        require(
            patients[a.patientId - 1].account == msg.sender ||
            doctors[a.doctorId - 1].account == msg.sender ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Unauthorized"
        );
        a.isDeleted = true;
        emit Events.AppointmentDeleted(appointmentId);
    }

    function canView(uint256 patientId, address viewer) public view returns (bool) {
        return (
            recordAccess[patientId][viewer] ||
            patients[patientId - 1].account == viewer ||
            hasRole(DEFAULT_ADMIN_ROLE, viewer)
        );
    }

    function _validateBookingParties(address doctorAddress) internal view returns (uint256 patientId, uint256 doctorId) {
        require(doctorAddress != address(0), "Invalid doctor address");
        doctorId = doctorIds[doctorAddress];
        require(doctorId != 0 && !doctors[doctorId - 1].isDeleted, "Doctor not found");
        patientId = patientIds[msg.sender];
        require(patientId != 0 && !patients[patientId - 1].isDeleted, "Patient not found");
    }

    function _splitAndTransferFee(address doctorAddress) internal returns (uint256 doctorShare, uint256 royalty) {
        royalty = (msg.value * 5) / 100;
        doctorShare = msg.value - royalty;
        require(doctorShare > 0, "Doctor share too low");
        require(royalty > 0, "Royalty too low");
        (bool sentDoctor, ) = doctorAddress.call{value: doctorShare}("");
        require(sentDoctor, "Payment to doctor failed");
        (bool sentOwner, ) = appOwner.call{value: royalty}("");
        require(sentOwner, "Royalty payment failed");
    }

    receive() external payable {}
}

// import "hardhat/console.sol";

// import {PatientsLib} from "./modules/PatientsLib.sol";
// import {DoctorsLib} from "./modules/DoctorsLib.sol";
// import {RecordsLib} from "./modules/RecordsLib.sol";
// import {AppointmentsLib} from "./modules/AppointmentsLib.sol";

// import {DataTypes} from "./shared/DataTypes.sol";

// contract HealthcareRecordSystem is AccessControl {
//     using PatientsLib for PatientsLib.Storage;
//     using DoctorsLib for DoctorsLib.Storage;
//     using RecordsLib for RecordsLib.Storage;
//     using AppointmentsLib for AppointmentsLib.Storage;

//     bytes32 public constant DOCTOR_ROLE = keccak256("DOCTOR_ROLE");
//     bytes32 public constant PATIENT_ROLE = keccak256("PATIENT_ROLE");

//     address public appOwner;
//     uint256 public minFee = 0.0001 ether;

//     PatientsLib.Storage private patientStore;
//     DoctorsLib.Storage private doctorStore;
//     RecordsLib.Storage private recordStore;
//     AppointmentsLib.Storage private appointmentStore;

//     constructor() {
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         appOwner = msg.sender;
//     }

//     // Patient Functions
//     function registerPatient(string memory name, uint256 age, string memory gender) external {
//         patientStore.register(name, age, gender, msg.sender);
//         _grantRole(PATIENT_ROLE, msg.sender);
//     }

//     function grantAccess(uint256 patientId, address viewer) external {
//         patientStore.grantAccess(patientId, viewer, msg.sender);
//     }

//     function revokeAccess(uint256 patientId, address viewer) external {
//         patientStore.revokeAccess(patientId, viewer, msg.sender);
//     }
//     function getPatientId(address patient) external view returns (uint256) {
//     return patientStore.patientIds[patient];
// }
//     function getMyPatientProfile() external view returns (DataTypes.Patient memory) {
//         return patientStore.getProfile(msg.sender);
//     }

//     function getSinglePatient(uint256 patientId) external view returns (DataTypes.Patient memory) {
//         return patientStore.getById(patientId);
//     }

//     // Doctor Functions
//     function registerDoctor(
//         string memory name,
//         string memory specialization,
//         string memory licenseId
//     ) external {
//         doctorStore.register(name, specialization, licenseId, msg.sender);
//         _grantRole(DOCTOR_ROLE, msg.sender);
//     }

//     function getDoctorIdByName(string memory name) external view returns (uint256) {
//         return doctorStore.getByName(name);
//     }

//     function getAllDoctors() external view returns (DataTypes.Doctor[] memory) {
//         return doctorStore.getAll();
//     }

//     // Medical Record Functions
//     function addMedicalRecord(
//         uint256 patientId,
//         string memory ipfsUrl,
//         string memory patientName,
//         string memory diagnosis
//     ) external onlyRole(PATIENT_ROLE) {
//         DataTypes.Patient memory patient = patientStore.getById(patientId);
//         require(patient.account == msg.sender, "Not patient owner");
//         recordStore.addRecord(patientId, ipfsUrl, patientName, diagnosis);
//     }

//     function prescribeMedicine(uint256 recordId, string memory prescription) external onlyRole(DOCTOR_ROLE) {
//         uint256 doctorId = doctorStore.doctorIds[msg.sender];
//         recordStore.addPrescription(recordId, prescription, doctorId);
//     }

//     function getPatientMedicalRecords(uint256 patientId) external view returns (DataTypes.MedicalRecord[] memory) {
//         require(
//             patientStore.canView(patientId, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
//             "Unauthorized"
//         );
//         return recordStore.getPatientRecords(patientId);
//     }

//     function getAllPatientsRecords() external view onlyRole(DEFAULT_ADMIN_ROLE) returns (DataTypes.Patient[] memory) {
//         return patientStore.getAllPatients();
//     }

//     // Appointment
//     function bookAppointment(address doctorAddress, uint256 timestamp) external payable onlyRole(PATIENT_ROLE) returns (uint256) {
//         uint256 doctorId = doctorStore.doctorIds[doctorAddress];
//         require(doctorId != 0, "Doctor not found");

//         uint256 patientId = patientStore.patientIds[msg.sender];
//         require(patientId != 0, "Patient not found");

//         uint256 id = appointmentStore.book(
//             patientId,
//             doctorId,
//             doctorAddress,
//             appOwner,
//             timestamp,
//             minFee,
//             msg.sender,
//             msg.value
//         );

//         patientStore.recordAccess[patientId][doctorAddress] = true;

//         return id;
//     }

//     // Soft Deletes
//     function deletePatient(uint256 patientId) external onlyRole(DEFAULT_ADMIN_ROLE) {
//         patientStore.softDelete(patientId);
//     }

//     function deleteDoctor(uint256 doctorId) external onlyRole(DEFAULT_ADMIN_ROLE) {
//         doctorStore.softDelete(doctorId);
//     }
//     function hasPatientRole(address account) external view returns (bool) {
//     return hasRole(PATIENT_ROLE, account);
// }
//     function hasDoctorRole(address account) external view returns (bool) {
//     return hasRole(DOCTOR_ROLE, account);
// }

//     function deleteMedicalRecord(uint256 recordId) external {
//         DataTypes.MedicalRecord memory rec = recordStore.records[recordId - 1];
//         DataTypes.Patient memory patient = patientStore.getById(rec.patientId);
//         bool isAdmin = hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         recordStore.softDelete(recordId, msg.sender, patient.account, isAdmin);
//     }

//     function deleteAppointment(uint256 appointmentId) external {
//         DataTypes.Appointment memory appt = appointmentStore.appointments[appointmentId - 1];
//         DataTypes.Patient memory patient = patientStore.getById(appt.patientId);
//         DataTypes.Doctor memory doctor = doctorStore.doctors[appt.doctorId - 1];
//         bool isAdmin = hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         appointmentStore.softDelete(appointmentId, msg.sender, patient.account, doctor.account, isAdmin);
//     }
// }



// pragma solidity ^0.8.24;

// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "./PatientModule.sol";
// import "./DoctorModule.sol";
// import "./MedicalRecordModule.sol";
// import "./AppointmentModule.sol";

// contract HealthcareRecordSystem is
//     AccessControl,
//     PatientModule,
//     DoctorModule,
//     MedicalRecordModule,
//     AppointmentModule
// {
//     bytes32 public constant DOCTOR_ROLE = keccak256("DOCTOR_ROLE");
//     bytes32 public constant PATIENT_ROLE = keccak256("PATIENT_ROLE");

//     constructor() {
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         appOwner = msg.sender;
//         minFee = 0.0001 ether;
//     }

//     function deletePatient(uint256 patientId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
//         require(patientId > 0 && patientId <= patients.length, "Invalid patient");
//         patients[patientId - 1].isDeleted = true;
//         emit PatientDeleted(patientId);
//     }

//     function deleteDoctor(uint256 doctorId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
//         require(doctorId > 0 && doctorId <= doctors.length, "Invalid doctor");
//         doctors[doctorId - 1].isDeleted = true;
//         emit DoctorDeleted(doctorId);
//     }

//     function addMedicalRecord(
//         uint256 patientId,
//         string memory ipfsUrl,
//         string memory patientName,
//         string memory diagnosis
//     ) external override onlyRole(PATIENT_ROLE) onlyPatientOwner(patientId) {
//         require(!patients[patientId - 1].isDeleted, "Patient deleted");

//         recordCount++;
//         records.push(MedicalRecord({
//             id: recordCount,
//             patientId: patientId,
//             doctorId: 0,
//             ipfsUrl: ipfsUrl,
//             patientName: patientName,
//             diagnosis: diagnosis,
//             prescription: "",
//             timestamp: block.timestamp,
//             isDeleted: false
//         }));

//         emit MedicalRecordAdded(recordCount, patientId, 0);
//     }

//     function prescribeMedicine(uint256 recordId, string memory prescription)
//         external
//         override
//         onlyRole(DOCTOR_ROLE)
//     {
//         require(recordId > 0 && recordId <= records.length, "Record not found");
//         MedicalRecord storage rec = records[recordId - 1];
//         require(!rec.isDeleted, "Record deleted");

//         rec.prescription = prescription;
//         rec.doctorId = doctorIds[msg.sender];

//         emit PrescriptionAdded(recordId, prescription);
//     }

//     function getPatientMedicalRecords(uint256 patientId)
//         external
//         view
//         override
//         returns (MedicalRecord[] memory)
//     {
//         require(canView(patientId, msg.sender), "Unauthorized");

//         uint256 count;
//         for (uint256 i = 0; i < records.length; i++) {
//             if (records[i].patientId == patientId && !records[i].isDeleted) count++;
//         }

//         MedicalRecord[] memory output = new MedicalRecord[](count);
//         uint256 j;
//         for (uint256 i = 0; i < records.length; i++) {
//             if (records[i].patientId == patientId && !records[i].isDeleted) {
//                 output[j++] = records[i];
//             }
//         }
//         return output;
//     }

//     function getAllPatientsRecords()
//         external
//         view
//         override
//         onlyRole(DEFAULT_ADMIN_ROLE)
//         returns (MedicalRecord[] memory)
//     {
//         return records;
//     }

//     function deleteMedicalRecord(uint256 recordId) external override {
//         require(recordId > 0 && recordId <= records.length, "Record not found");
//         MedicalRecord storage rec = records[recordId - 1];
//         require(
//             patients[rec.patientId - 1].account == msg.sender ||
//             hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
//             "Unauthorized"
//         );

//         rec.isDeleted = true;
//         emit RecordDeleted(recordId);
//     }

//     function bookAppointment(address doctorAddress, uint256 timestamp)
//         external
//         payable
//         override
//         onlyRole(PATIENT_ROLE)
//         returns (uint256)
//     {
//         require(msg.value >= minFee, "Amount too small");
//         require(timestamp > block.timestamp, "Invalid appointment time");

//         (uint256 patientId, uint256 doctorId) = _validateBookingParties(doctorAddress);

//         uint256 id = ++appointmentCount;
//         (uint256 doctorShare, uint256 royalty) = _splitAndTransferFee(doctorAddress);

//         appointments.push(Appointment({
//             id: id,
//             patientId: patientId,
//             doctorId: doctorId,
//             timestamp: timestamp,
//             isConfirmed: false,
//             isDeleted: false,
//             isRejected: false,
//             fee: msg.value
//         }));

//         recordAccess[patientId][doctorAddress] = true;

//         emit AppointmentBooked(id, patientId, doctorId);
//         emit PaymentMade(paymentCount++, msg.sender, doctorAddress, doctorShare, royalty, "Appointment Booking");

//         return id;
//     }

//     function _validateBookingParties(address doctorAddress)
//         internal
//         view
//         override
//         returns (uint256 patientId, uint256 doctorId)
//     {
//         require(doctorAddress != address(0), "Invalid doctor address");
//         doctorId = doctorIds[doctorAddress];
//         require(doctorId != 0 && !doctors[doctorId - 1].isDeleted, "Doctor not found");

//         patientId = patientIds[msg.sender];
//         require(patientId != 0 && !patients[patientId - 1].isDeleted, "Patient not found");
//     }

//     function _splitAndTransferFee(address doctorAddress)
//         internal
//         override
//         returns (uint256 doctorShare, uint256 royalty)
//     {
//         royalty = (msg.value * 5) / 100;
//         doctorShare = msg.value - royalty;

//         require(doctorShare > 0, "Doctor share too low");
//         require(royalty > 0, "Royalty too low");

//         (bool sentDoctor, ) = doctorAddress.call{value: doctorShare}("");
//         require(sentDoctor, "Payment to doctor failed");

//         (bool sentOwner, ) = appOwner.call{value: royalty}("");
//         require(sentOwner, "Royalty payment failed");
//     }

//     function deleteAppointment(uint256 appointmentId) external override {
//         require(appointmentId > 0 && appointmentId <= appointments.length, "Appointment not found");
//         Appointment storage appt = appointments[appointmentId - 1];
//         require(
//             patients[appt.patientId - 1].account == msg.sender ||
//             doctors[appt.doctorId - 1].account == msg.sender ||
//             hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
//             "Unauthorized"
//         );
//         appt.isDeleted = true;
//         emit AppointmentDeleted(appointmentId);
//     }
// }
