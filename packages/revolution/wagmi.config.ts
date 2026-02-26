import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";

export default defineConfig({
  out: "package/wagmiGenerated.ts",
  plugins: [
    foundry({
      forge: {
        build: false,
      },
      include: [
        "CultureIndex",
        "AuctionHouse",
        "RevolutionBuilder",
        "RevolutionPointsEmitter",
        "RevolutionPoints",
        "VRGDAC",
        "Descriptor",
        "MaxHeap",
        "RevolutionVotingPower",
        "RevolutionToken",
        "RevolutionDAOLogicV1",
        "DAOExecutor",
        "RevolutionGrants",
        // extensions
        "ContestBuilder",
        "BaseContest",
        "GnosisDAOExecutor",
      ].map((contractName) => `${contractName}.json`),
    }),
  ],
});
