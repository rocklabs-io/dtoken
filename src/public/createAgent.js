import * as ic from "@dfinity/agent";

// FIX: You may need an appropriate loader to handle this file type
// import { Ed25519KeyIdentity } from "@dfinity/authentication";

const createAgent = (host) => {
  const { HttpAgent, IDL, Principal } = ic;
  const keyPair = ic.generateKeyPair();
  const agent = new HttpAgent({
    principal: Principal.selfAuthenticating(keyPair.publicKey),
    host,
  });
  agent.addTransform(ic.makeNonceTransform());
  agent.setAuthTransform(ic.makeAuthTransform(keyPair));
  return agent;
}

// const LOCAL_KEY_ID = "testKey";
// const { HttpAgent } = ic;

// const createAgent = () => {
//   var keyIdentity = undefined;
//   var keyMaybe = window.localStorage.getItem(LOCAL_KEY_ID);

//   if (!keyMaybe) {
//     const createRandomSeed = () => crypto.getRandomValues(new Uint8Array(32));
//     keyIdentity = Ed25519KeyIdentity.generate(createRandomSeed());
//     window.localStorage.setItem(LOCAL_KEY_ID, JSON.stringify(keyIdentity.toJSON()));
//   } else {
//     keyIdentity = Ed25519KeyIdentity.fromJSON(keyMaybe);
//   }
//   let agent = new HttpAgent({
//     identity: keyIdentity,
//   });

//   agent.addTransform(ic.makeNonceTransform());
//   agent.addTransform(ic.makeExpiryTransform(5 * 60 * 1000));
//   return agent;
// };

export default createAgent;