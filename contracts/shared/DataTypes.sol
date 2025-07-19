// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DataTypes {
    struct Patient {
        uint256 id;
        string name;
        uint256 age;
        string gender;
        string avatar;
        address account;
        bool isDeleted;
    }

    struct Doctor {
        uint256 id;
        string name;
        string specialization;
        string licenseId;
        address account;
        string biography;
        string avatar;
        bool isDeleted;
    }

    struct MedicalRecord {
        uint256 id;
        uint256 patientId;
        uint256 doctorId;
        string ipfsUrl;
        string patientName;
        string diagnosis;
        string prescription;
        uint256 timestamp;
        bool isDeleted;
    }

    struct Appointment {
        uint256 id;
        uint256 patientId;
        uint256 doctorId;
        uint256 timestamp;
        bool isConfirmed;
        bool isDeleted;
        bool isRejected;
        uint256 fee;
    }

    struct Payment {
        uint256 id;
        address from;
        address to;
        uint256 amount;
        uint256 royalty;
        uint256 timestamp;
        string purpose;
    }
}
