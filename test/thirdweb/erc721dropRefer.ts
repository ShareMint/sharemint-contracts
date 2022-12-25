import { ethers } from "hardhat";
import { expect } from "chai";
import { ERC721DropRefer } from "typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("ERC721Drop delayed reveal test", function () {
  let erc721DropRefer: ERC721DropRefer;
  let signer: SignerWithAddress;

  before(async () => {
    [signer] = await ethers.getSigners();
    erc721DropRefer = await ethers
      .getContractFactory("ERC721DropRefer")
      .then(f =>
        f
          .connect(signer)
          .deploy("name", "symbol", ethers.constants.AddressZero, 0, ethers.constants.AddressZero, 100, signer.address),
      );
  });

  it("Should let you mint without a referrer", async () => {});

  it("Should let you mint with a referrer and default reward", async () => {});

  it("Should let you mint with a referral signature and custom reward", async () => {});
});
