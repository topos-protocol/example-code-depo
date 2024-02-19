import { expect } from "chai";
import hre from "hardhat";

// Simple check that it's something, and not nothing.
const isSomething = (thing: any) => {
  expect(thing).to.not.equal("");
  expect(thing).to.not.equal(undefined);
}

// Send too much data to a store function, and expect an unknown RPC error.
const expectUnknownRPCError = async (store: any) => {
  await expect(store(["0123456789".repeat(26)])).to.be.rejectedWith("An unknown RPC error occurred.");
}

describe("memory-1", function () {
  it("Should successfully deploy the memory-1 contract", async function () {
    const memory1 = await hre.viem.deployContract(
      "contracts/memory-1.sol:Memory"
    );
    // This should always succeed. It's here just as a placeholder to build from, conceptually.
    isSomething(memory1.address)
  });

  it("Can call the basic store function of the memory-2 contract", async function () {
    const memory2 = await hre.viem.deployContract(
      "contracts/memory-2.sol:Memory"
    );
    const tx = await memory2.write.store(["This is some data."]);
    isSomething(tx);
  });

  it("Can call the basic store function of the memory-3 contract", async function () {
    const memory3 = await hre.viem.deployContract(
      "contracts/memory-3.sol:Memory"
    );
    const tx = await memory3.write.store(["This is some data."]);
    isSomething(tx);
  });

  it("Gets a contract revert when trying to send too much data to the memory-3 store function", async function () {
    const memory3 = await hre.viem.deployContract(
      "contracts/memory-3.sol:Memory"
    );

    await expectUnknownRPCError(memory3.write.store);
  });

  it("Can store and retrieve data from the memory contract, and it reverts as expected", async function () {
    const memory = await hre.viem.deployContract(
      "contracts/memory.sol:Memory"
    );
    await expectUnknownRPCError(memory.write.store);

    const tx = await memory.write.store(["This is some data."]);
    isSomething(tx);

    const data = await memory.read.recall();
    expect(data).to.equal("This is some data.");
  })
});
