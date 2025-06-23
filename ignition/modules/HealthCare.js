// ignition/modules/DeployHealthcare.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("HealthcareRecordSystem", (m) => {
  // Step 1: Deploy Libraries
  // const patientsLib = m.library("PatientsLib");
  // const doctorsLib = m.library("DoctorsLib");
  // const recordsLib = m.library("RecordsLib");
  // const appointmentsLib = m.library("AppointmentsLib");

  // Step 2: Deploy Main Contract with Linked Libraries
  const healthcare = m.contract("HealthcareRecordSystem", [], {
    // libraries: {
    //   "contracts/modules/PatientsLib.sol:PatientsLib": patientsLib,
    //   "contracts/modules/DoctorsLib.sol:DoctorsLib": doctorsLib,
    //   "contracts/modules/RecordsLib.sol:RecordsLib": recordsLib,
    //   "contracts/modules/AppointmentsLib.sol:AppointmentsLib": appointmentsLib,
    // },
  });

  return { healthcare };
});


// // This setup uses Hardhat Ignition to manage smart contract deployments.
// // Learn more about it at https://hardhat.org/ignition

// const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");


// module.exports = buildModule("HealthcareRecordSystem", (m) => {
//   const healthcareRecordSystem = m.contract("HealthcareRecordSystem", [], {

  
//   });

//   return { healthcareRecordSystem };
// });
