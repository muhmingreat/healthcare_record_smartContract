// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;


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

    mapping(uint256 => uint256) public latestAppointmentByPatient; // patientId => latest appointment index
    mapping(address => uint256[]) public userPayments;
    mapping(address => uint256) public addressToPatientId;
    mapping(address => uint256) public addressToDoctorId;
    mapping(uint256 => mapping(address => bool)) public recordAccess;

 event PrescriptionAdded(uint256 indexed recordId, string prescription);
  event MedicalRecordAdded(uint256 indexed id, uint256 indexed patientId, uint256 indexed doctorId);
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        appOwner = msg.sender;
    }

    modifier onlyPatientOwner(uint256 patientId) {
        require(patientId != 0 && patientId <= patients.length, "Invalid patient ID");
        require(patients[patientId - 1].account == msg.sender, "Not patient owner");
        _;
    }

    function registerPatient(string memory name, uint256 age, string memory gender, string memory avatar)
        external
        override
    {
        require(msg.sender != address(0), "Invalid sender");


        uint256 _id = patients.length + 1;

        patients.push(DataTypes.Patient({
            id: _id,
            name: name,
            age: age,
            gender: gender,
            account: msg.sender,
            avatar: avatar,
            isDeleted: false
        }));

        addressToPatientId[msg.sender] = _id;
        _grantRole(PATIENT_ROLE, msg.sender);
        emit Events.PatientRegistered(_id, msg.sender);
    }

    function getMyPatientProfile() public view override returns (DataTypes.Patient memory) {
        uint256 id = addressToPatientId[msg.sender];
        require(id != 0, "Patient not found");
        require(!patients[id - 1].isDeleted, "Patient is deleted");
        return patients[id - 1];
    }

    function getSinglePatient(uint256 patientId) external view override returns (DataTypes.Patient memory) {
        require(patientId != 0 && patientId <= patients.length, "Invalid patient ID");
        require(!patients[patientId - 1].isDeleted, "Patient is deleted");
        return patients[patientId - 1];
    }

    function registerDoctor(string memory name, string memory specialization, string memory licenseId, string memory biography, string memory avatar)
        external
        override
    {
        require(msg.sender != address(0), "Invalid sender");
        require(addressToDoctorId[msg.sender] == 0, "Already registered");
        uint256 _id = doctors.length + 1;

        doctors.push(DataTypes.Doctor({
            id: _id,
            name: name,
            specialization: specialization,
            licenseId: licenseId,
            biography: biography,
            account: msg.sender,
            avatar: avatar,
            isDeleted: false
        }));

        addressToDoctorId[msg.sender] = _id;
        _grantRole(DOCTOR_ROLE, msg.sender);
        emit Events.DoctorRegistered(_id, msg.sender);
    }

    function getAllDoctors() external view override returns (DataTypes.Doctor[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < doctors.length; i++) {
            if (!doctors[i].isDeleted) count++;
        }
        DataTypes.Doctor[] memory result = new DataTypes.Doctor[](count);
        uint256 j;
        for (uint256 i = 0; i < doctors.length; i++) {
            if (!doctors[i].isDeleted) result[j++] = doctors[i];
        }
        return result;
    }
    function getSingleDoctor(uint256 doctorId) external view override returns (DataTypes.Doctor memory) {
        require(doctorId != 0 && doctorId <= doctors.length, "Invalid doctor ID");
        require(!doctors[doctorId - 1].isDeleted, "Doctor is deleted");
        return doctors[doctorId - 1];
    }
    function getDoctorProfile() external view override returns (DataTypes.Doctor memory) {
        uint256 id = addressToDoctorId[msg.sender];
        require(id != 0, "Doctor not found");
        require(!doctors[id - 1].isDeleted, "Doctor is deleted");
        return doctors[id - 1];
    }

      function addMedicalRecord(
    uint256 patientId,
    string memory ipfsUrl,
    string memory patientName,
    string memory diagnosis
) external onlyRole(PATIENT_ROLE) onlyPatientOwner(patientId) {

    uint256 appointmentIndex = latestAppointmentByPatient[patientId];


    DataTypes.Appointment memory appointment = appointments[appointmentIndex];
    require(!appointment.isDeleted, "Invalid appointment");

    
    uint256 doctorId = appointment.doctorId;
    require(doctorId != 0, "Doctor not assigned");

    
    uint256 id = records.length + 1;
    records.push(DataTypes.MedicalRecord({
        id: id,
        patientId: patientId,
        doctorId: doctorId,
        ipfsUrl: ipfsUrl,
        patientName: patientName,
        diagnosis: diagnosis,
        prescription: "",
        timestamp: block.timestamp,
        isDeleted: false
    }));

    
    emit MedicalRecordAdded(id, patientId, doctorId);
}
function bookAppointment(
    address doctorAddress,
    uint256 timestamp
) external payable override onlyRole(PATIENT_ROLE) returns (uint256) {
    require(msg.sender != address(0), "Invalid sender");
    require(doctorAddress != address(0), "Zero address");
    require(msg.value >= minFee, "Insufficient fee");
    require(timestamp > block.timestamp, "Invalid timestamp");

    (uint256 patientId, uint256 doctorId) = _validateBookingParties(doctorAddress);
    uint256 id = appointments.length ;

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

    latestAppointmentByPatient[patientId] = id; 
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
    emit Events.PaymentMade(
        payments.length,
        msg.sender,
        doctorAddress,
        share,
        royalty,
        "Appointment Booking"
    );

    return id;
}

function getMedicalRecordsByDoctor(uint256 doctorId) external view returns (DataTypes.MedicalRecord[] memory) {
    uint256 count;

    // First pass: count how many records belong to the doctor and are not deleted
    for (uint256 i = 0; i < records.length; i++) {
        if (records[i].doctorId == doctorId && !records[i].isDeleted) {
            count++;
        }
    }

    // Create a fixed-size array to hold matching records
    DataTypes.MedicalRecord[] memory result = new DataTypes.MedicalRecord[](count);
    uint256 index;

    // Second pass populate the result array
    for (uint256 i = 0; i < records.length; i++) {
        if (records[i].doctorId == doctorId && !records[i].isDeleted) {
            result[index] = records[i];
            index++;
        }
    }

    return result;
}

    function prescribeMedicine(uint256 recordId, string memory prescription)
        external
        override
        onlyRole(DOCTOR_ROLE)
    {
        require(recordId != 0 && recordId <= records.length, "Invalid record ID");
        DataTypes.MedicalRecord storage rec = records[recordId - 1];
        require(!rec.isDeleted, "Record is deleted");
        rec.prescription = prescription;
        rec.doctorId = addressToDoctorId[msg.sender];
        emit PrescriptionAdded(recordId, prescription);
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
        uint256 count = 0;
        for (uint256 i = 0; i < patients.length; i++) {
            if (!patients[i].isDeleted) count++;
        }
        DataTypes.Patient[] memory result = new DataTypes.Patient[](count);
        uint256 j;
        for (uint256 i = 0; i < patients.length; i++) {
            if (!patients[i].isDeleted) result[j++] = patients[i];
        }
        return result;
    }


    function deleteMedicalRecord(uint256 recordId) external override {
        require(recordId != 0 && recordId <= records.length, "Invalid record ID");
        DataTypes.MedicalRecord storage rec = records[recordId - 1];
        require(
            rec.patientId != 0 &&
            (patients[rec.patientId - 1].account == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender)),
            "Unauthorized"
        );
        rec.isDeleted = true;
        emit Events.RecordDeleted(recordId);
    }

    function deletePatient(uint256 patientId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(patientId != 0 && patientId <= patients.length, "Invalid patient ID");
        patients[patientId - 1].isDeleted = true;
        address patientAddr = patients[patientId - 1].account;
        _revokeRole(PATIENT_ROLE, patientAddr);
        emit Events.PatientDeleted(patientId);
    }

    function deleteDoctor(uint256 doctorId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(doctorId != 0 && doctorId <= doctors.length, "Invalid doctor ID");
        doctors[doctorId - 1].isDeleted = true;
        address doctorAddr = doctors[doctorId - 1].account;
        _revokeRole(DOCTOR_ROLE, doctorAddr);
        emit Events.DoctorDeleted(doctorId);
    }


    function deleteAppointment(uint256 appointmentId) external override {
        require(appointmentId != 0 && appointmentId <= appointments.length, "Invalid appointment ID");
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
        if (patientId == 0 || patientId > patients.length) return false;
        DataTypes.Patient storage p = patients[patientId - 1];
        return (
            recordAccess[patientId][viewer] ||
            p.account == viewer ||
            hasRole(DEFAULT_ADMIN_ROLE, viewer)
        );
    }

    function _validateBookingParties(address doctorAddress)
        internal
        view
        returns (uint256 patientId, uint256 doctorId)
    {
        doctorId = addressToDoctorId[doctorAddress];
        require(doctorId != 0 && !doctors[doctorId - 1].isDeleted, "Doctor not found");

        patientId = addressToPatientId[msg.sender];
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
        require(sentOwner, "Payment to owner failed");
    }

    receive() external payable {}
}
