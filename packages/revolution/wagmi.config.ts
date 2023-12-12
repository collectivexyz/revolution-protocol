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
        "ERC20TokenEmitter",
        "NontransferableERC20Votes",
        "VRGDAC",
        "Descriptor",
        "MaxHeap",
        "VerbsToken",
        "VerbsDAOLogicV1",
      ].map((contractName) => `${contractName}.json`),
    }),
  ],
});
