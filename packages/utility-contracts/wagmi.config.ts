import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";

export default defineConfig({
  out: "package/wagmiGenerated.ts",
  plugins: [
    foundry({
      forge: {
        build: false,
      },
      include: ["UUPS", "ERC1967Proxy", "ERC1967Upgrade"].map(
        (contractName) => `${contractName}.json`
      ),
    }),
  ],
});
