const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BottleUp", function () {
  let bottleUp, rewardToken;
  let owner, user1, user2, addAdmin;

  beforeEach(async function () {
    // Get signers
    [owner, user1, user2, admin] = await ethers.getSigners();

    // Deploy the ERC20 token (reward token)
    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    rewardToken = await ERC20.deploy(
      "RewardToken",
      "RTK",
      ethers.parseEther("1000000000")
    );

    // Deploy the BottleRecycling contract
    const BottleUp = await ethers.getContractFactory("BottleUp");
    bottleUp = await BottleUp.deploy(await rewardToken.getAddress());
  });

  it("should register users", async function () {
    await bottleUp.connect(user1).registerUser("user1");
    const user1Profile = await bottleUp.users(user1.address);
    expect(user1Profile.username).to.equal("user1");

    await bottleUp.connect(user2).registerUser("user2");
    const user2Profile = await bottleUp.users(user2.address);
    expect(user2Profile.username).to.equal("user2");
  });

  it("should submit bottles", async function () {
    await bottleUp.connect(user1).registerUser("user1");
    await bottleUp.connect(user1).submitBottles(5);
    const user1Profile = await bottleUp.users(user1.address);
    expect(user1Profile.totalBottlesSubmitted).to.equal(5);
  });

  it("should collect bottles by admin", async function () {
    await bottleUp.connect(user1).registerUser("user1");
    await bottleUp.connect(user1).submitBottles(10);

    await bottleUp.collectBottles(user1.address, 0);

    const user1Profile = await bottleUp.users(user1.address);
    expect(user1Profile.totalBottlesCollected).to.equal(10);
  });

  it("should redeem tokens based on collected bottles", async function () {
    await rewardToken.transfer(
      await bottleUp.getAddress(),
      ethers.parseEther("10000")
    );
    await bottleUp.connect(user1).registerUser("user1");
    await bottleUp.connect(user1).submitBottles(10);

    await bottleUp.collectBottles(user1.address, 0);

    await bottleUp.connect(user1).redeemTokens();

    const user1Profile = await bottleUp.users(user1.address);
    expect(user1Profile.tokenBalance).to.equal(1); // 1 token for 10 bottles
  });

  it("should return top users by total bottles collected", async function () {
    await bottleUp.connect(user1).registerUser("user1");
    await bottleUp.connect(user2).registerUser("user2");

    await bottleUp.connect(user1).submitBottles(15);
    await bottleUp.connect(user2).submitBottles(25);

    await bottleUp.collectBottles(user1.address, 0);
    await bottleUp.collectBottles(user2.address, 0);

    const topUsers = await bottleUp.getTopUsers(2);
    expect(topUsers[0].userAddress).to.equal(user2.address); // user2 should be the top
    expect(topUsers[1].userAddress).to.equal(user1.address);
  });
  describe("Admin Management", function () {
    it("Should add a new admin", async function () {
      // Add new admin by owner
      await bottleUp.connect(owner).addAdmin(admin.address);
      expect(await bottleUp.admins(admin.address)).to.be.true;
    });

    it("Should fail to add a new admin if not called by owner", async function () {
      // Try to add admin by someone other than owner (should fail)
      await expect(
        bottleUp.connect(user1).addAdmin(admin.address)
      ).to.be.rejectedWith();
    });

    it("Should remove an admin", async function () {
      // Add an admin first
      await bottleUp.connect(owner).addAdmin(admin.address);
      expect(await bottleUp.admins(admin.address)).to.be.true;

      // Remove the admin
      await bottleUp.connect(owner).removeAdmin(admin.address);
      expect(await bottleUp.admins(admin.address)).to.be.false;
    });

    it("Should fail to remove admin if not called by owner", async function () {
      // Add an admin first
      await bottleUp.connect(owner).addAdmin(admin.address);
      expect(await bottleUp.admins(admin.address)).to.be.true;

      // Try to remove admin by someone other than owner (should fail)
      await expect(
        bottleUp.connect(user1).removeAdmin(admin.address)
      ).to.be.rejectedWith()
    });
  });
});
