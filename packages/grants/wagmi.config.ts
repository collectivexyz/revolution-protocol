import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";

export default defineConfig({
  out: "package/wagmiGenerated.ts",
  plugins: [
    foundry({
      forge: {
        build: false,
      },
      include: ["RecipientSuperAppFactory", "RecipientSuperApp", "SQFSuperFluidStrategy"].map(
        (contractName) => `${contractName}.json`
      ),
    }),
  ],
});
