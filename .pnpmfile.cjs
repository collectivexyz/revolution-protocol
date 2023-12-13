function readPackage(pkg, context) {
  if (pkg.name === "@cobuilding/revolution") {
    pkg.dependencies = {
      ...pkg.dependencies,
      "@cobuilding/protocol-rewards": "0.9.0",
    };
  }

  return pkg;
}

module.exports = {
  hooks: {
    readPackage,
  },
};
