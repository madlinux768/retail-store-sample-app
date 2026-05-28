module.exports = {
  "*.{js,jsx,ts,tsx,json,md,yaml,yml}": "prettier --write",
  "*.java": "prettier --write",
  "*.xml": "prettier --write",
  "*.go": "gofmt -w",
  "*.tf": (files) => [
    `terraform fmt ${files.join(" ")}`,
    `tflint ${files.map((f) => `--filter=${f}`).join(" ")}`,
  ],
  "samples/**/*":
    "yarn nx run-many -t update-samples --projects=tag:sample",
};
