id: 8dglro8ootvrhtua84qcmx402ywi2dw0d1u8nfx3oc42z8dw
name: ziglint
license: MIT
description: A linting suite for Zig
min_zig_version: 0.11.0
bin: True
provides: ["ziglint"]
root_dependencies:
  - src: git https://github.com/nektro/zig-range
  - src: git https://github.com/nektro/zig-flag
