const { keccak256, toUtf8Bytes } = require("ethers/lib/utils");
const errors = [ "UnauthorizedAccess()", "NotPatientOwner()" ];

for (const e of errors) {
  if (keccak256(toUtf8Bytes(e)).slice(0,10) === "0xe2517d3f") {
    console.log("Match ->", e);
    break;
  }
}
