// ignition/modules/DeployHealthcare.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("HealthcareRecordSystem", (m) => {

  const healthcare = m.contract("HealthcareRecordSystem", [], {
   
  });

  return { healthcare };
});

