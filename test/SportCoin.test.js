const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SportCoin Ecosystem", function () {
  let SportCoin, EngagementRewards, RedemptionStore;
  let spc, rewards, store;
  let owner, user1, user2, backendSigner, treasury;

  beforeEach(async function () {
    [owner, user1, user2, backendSigner, treasury] = await ethers.getSigners();

    // 1. Deploy SportCoin
    const SportCoinFactory = await ethers.getContractFactory("SportCoin");
    spc = await SportCoinFactory.deploy();
    await spc.waitForDeployment();

    // 2. Deploy EngagementRewards
    const RewardsFactory = await ethers.getContractFactory("EngagementRewards");
    rewards = await RewardsFactory.deploy(await spc.getAddress(), backendSigner.address);
    await rewards.waitForDeployment();

    // 3. Deploy RedemptionStore
    const StoreFactory = await ethers.getContractFactory("RedemptionStore");
    store = await StoreFactory.deploy(await spc.getAddress(), treasury.address);
    await store.waitForDeployment();

    // 4. Setup Roles
    const MINTER_ROLE = await spc.MINTER_ROLE();
    await spc.grantRole(MINTER_ROLE, await rewards.getAddress());
  });

  describe("EngagementRewards (Earning)", function () {
    it("Should allow valid signature claim", async function () {
      const amount = ethers.parseEther("10"); // 10 SPC
      const nonce = "unique-event-id-123";
      
      // Hash message exactly as in Solidity: keccak256(user, amount, nonce, contract)
      // Solidity: abi.encodePacked(msg.sender, amount, nonce, address(this))
      const contractAddr = await rewards.getAddress();
      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "string", "address"],
        [user1.address, amount, nonce, contractAddr]
      );
      
      // Sign with backend wallet
      const messageBytes = ethers.getBytes(messageHash);
      const signature = await backendSigner.signMessage(messageBytes);

      // User claims
      await expect(rewards.connect(user1).claimReward(amount, nonce, signature))
        .to.emit(rewards, "RewardClaimed")
        .withArgs(user1.address, amount, nonce);

      expect(await spc.balanceOf(user1.address)).to.equal(amount);
    });

    it("Should reject invalid signature", async function () {
      const amount = 100;
      const nonce = "id-1";
      const contractAddr = await rewards.getAddress();
      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "string", "address"],
        [user1.address, amount, nonce, contractAddr]
      );
      // Signed by USER, not BACKEND
      const signature = await user1.signMessage(ethers.getBytes(messageHash));

      await expect(
        rewards.connect(user1).claimReward(amount, nonce, signature)
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should prevent double-claim (Replay Attack)", async function () {
      const amount = 100;
      const nonce = "id-replay";
      const contractAddr = await rewards.getAddress();
      const messageHash = ethers.solidityPackedKeccak256(
        ["address", "uint256", "string", "address"],
        [user1.address, amount, nonce, contractAddr]
      );
      const signature = await backendSigner.signMessage(ethers.getBytes(messageHash));

      await rewards.connect(user1).claimReward(amount, nonce, signature);

      await expect(
        rewards.connect(user1).claimReward(amount, nonce, signature)
      ).to.be.revertedWith("Reward already claimed");
    });
  });

  describe("RedemptionStore (Spending)", function () {
    beforeEach(async function () {
      // Create item: ID 0, Cost 100, Stock 5
      await store.createItem("Jersey", 100, 5);
      
      // Mint tokens to user1 manually for testing (admin bypass)
      await spc.mint(user1.address, 200);
      
      // Approve store
      await spc.connect(user1).approve(await store.getAddress(), 200);
    });

    it("Should allow redemption and handle burn/treasury split", async function () {
      // 50% burn, 50% treasury (default)
      await store.connect(user1).redeemItem(0);

      const treasuryBalance = await spc.balanceOf(treasury.address);
      const userBalance = await spc.balanceOf(user1.address);
      
      expect(treasuryBalance).to.equal(50); // 50% of 100
      expect(userBalance).to.equal(100); // 200 - 100
      
      // Check burn (totalSupply reduced)
      // Initial mint: user1(200). Supply = 200.
      // Burned: 50. Supply should be 150.
      expect(await spc.totalSupply()).to.equal(150);
    });

    it("Should fail if out of stock", async function () {
      // Buy 5 times (empty stock)
      for(let i=0; i<5; i++) {
        await spc.mint(user1.address, 100);
        await spc.connect(user1).approve(await store.getAddress(), 100);
        await store.connect(user1).redeemItem(0);
      }

      await spc.mint(user1.address, 100);
      await spc.connect(user1).approve(await store.getAddress(), 100);
      
      await expect(
        store.connect(user1).redeemItem(0)
      ).to.be.revertedWith("Out of stock");
    });
  });
});
