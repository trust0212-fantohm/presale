import { ethers, upgrades } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // USDT token address (replace with actual USDT address)
    const usdtAddress = "0x..."; // Replace with actual USDT address
    // Treasury address (where USDT payments will be sent)
    const treasuryAddress = "0x..."; // Replace with actual treasury address
    
    // Minimum and maximum purchase amounts in USDT (6 decimals)
    const minPurchaseAmount = ethers.parseUnits("10", 6); // 10 USDT minimum
    const maxPurchaseAmount = ethers.parseUnits("10000", 6); // 10,000 USDT maximum

    console.log("Deploying saviTokenAddress...");
    
    const SaviToken = await ethers.getContractFactory("SAVI");
    const saviToken = await upgrades.deployProxy(SaviToken, [
        usdtAddress,
        treasuryAddress,
        minPurchaseAmount,
        maxPurchaseAmount
    ], {
        initializer: "initialize",
        kind: "uups"
    });

    await saviToken.waitForDeployment();
    const saviTokenAddress = await saviToken.getAddress();

    console.log("saviTokenAddress deployed to:", saviTokenAddress);

    // // Set phase times (example times, adjust as needed)
    // const now = Math.floor(Date.now() / 1000);
    // const phaseDuration = 7 * 24 * 60 * 60; // 7 days per phase

    // for (let i = 0; i < 6; i++) {
    //     const startTime = now + (i * phaseDuration);
    //     const endTime = startTime + phaseDuration;
        
    //     console.log(`Setting times for phase ${i}:`);
    //     console.log(`Start: ${new Date(startTime * 1000).toISOString()}`);
    //     console.log(`End: ${new Date(endTime * 1000).toISOString()}`);
        
    //     const tx = await saviToken.setPhaseTime(i, startTime, endTime);
    //     await tx.wait();
    // }

    console.log("Phase times set successfully");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 