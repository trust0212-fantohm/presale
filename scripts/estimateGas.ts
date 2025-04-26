import { ethers, upgrades } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Estimating gas with account:", deployer.address);

    // Example addresses - replace with actual ones
    const usdtAddress = "0xdac17f958d2ee523a2206206994597c13d831ec7"; // Mainnet USDT
    const treasuryAddress = deployer.address; // Example treasury address
    
    // Example purchase limits
    const minPurchaseAmount = ethers.parseUnits("10", 6); // 10 USDT
    const maxPurchaseAmount = ethers.parseUnits("10000", 6); // 10,000 USDT

    console.log("Estimating gas for deployment...");
    
    const SAVIToken = await ethers.getContractFactory("SAVI");
    
    // Deploy the contract to estimate gas
    const saviToken = await upgrades.deployProxy(SAVIToken, [
        usdtAddress,
        treasuryAddress,
        minPurchaseAmount,
        maxPurchaseAmount
    ], {
        initializer: "initialize",
        kind: "uups"
    });

    const deploymentTx = saviToken.deploymentTransaction();
    if (!deploymentTx) {
        throw new Error("Deployment transaction not found");
    }

    const receipt = await deploymentTx.wait();
    if (!receipt) {
        throw new Error("Transaction receipt not found");
    }
    
    // Get current gas price
    const gasPrice = await ethers.provider.getFeeData();
    const currentGasPrice = gasPrice.gasPrice || ethers.parseUnits("20", "gwei"); // Fallback to 20 gwei if not available

    // Calculate estimated cost in ETH
    const estimatedCost = receipt.gasUsed * currentGasPrice;
    
    console.log("\nGas Estimation Results:");
    console.log("----------------------");
    console.log(`Gas used: ${ethers.formatUnits(receipt.gasUsed, 0)}`);
    console.log(`Current gas price: ${ethers.formatUnits(currentGasPrice, "gwei")} gwei`);
    console.log(`Estimated cost: ${ethers.formatEther(estimatedCost)} ETH`);
    console.log(`Estimated cost in USD: $${(Number(ethers.formatEther(estimatedCost)) * 2000).toFixed(2)}`); // Assuming ETH price of $2000
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 