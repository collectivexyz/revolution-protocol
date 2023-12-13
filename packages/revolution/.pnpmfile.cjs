function readPackage(pkg, context) {
  if (pkg.name === "@cobuilding/revolution") {
    pkg.dependencies = {
      ...pkg.dependencies,
      "@cobuilding/protocol-rewards":
        "workspace:@cobuilding/protocol-rewards@*",
    };
  }

  return pkg;
}

module.exports = {
  hooks: {
    readPackage,
  },
};
