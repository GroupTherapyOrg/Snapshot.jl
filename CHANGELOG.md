# Changelog

## [0.1.1](https://github.com/GroupTherapyOrg/PlutoIslands.jl/compare/v0.1.0...v0.1.1) (2026-06-22)


### Features

* bond marshalling via WasmTarget.Bridge — String/NamedTuple/Vector/struct bonds ([122f4d4](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/122f4d48ffd65f6c1e032a6e3d4fd64bfd3e0577))
* expand coalesced image-stream commands in the canvas oracle ([2d80fab](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/2d80fab6c926e7b1bf3a41e6a0f9b044738aadb4))
* featured corpus draws with WasmMakie — every plot and image is a Figure ([7581807](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/7581807865bc526363b5ccafa5aa55907b922c26))
* full HTML-widget introspection — select/text/color/date bonds ([a07b7f7](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/a07b7f742800cb177b5e40be55b126e79170362d))
* html-wrapper bodies + raw-HTML widget introspection ([e9ed6f6](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/e9ed6f6f6aedfac3ce64a12808dbf417cac22a9a))
* low-hanging-fruit batch — toplevel exprs, tuple trees, transform_value, BigInt, stacktrace cells ([d6760f8](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/d6760f8825961b48f6a83ba2650415215b2ad5f1))
* repr-flavoured plain bodies + full bridge-era re-export — 17/67 groups ship ([ef9426e](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/ef9426efdefe2bc5cd12c4a982e035ef5180d0cf))
* tree-viewer bodies via the bridge read-side + notebook-env sandbox ([b4e508d](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/b4e508d85b077506012d684e2d281172f14444ae))


### Bug Fixes

* exported initial state matches widget defaults (synthetic-initial groups) ([4f73cdf](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/4f73cdf4f86582f73c9426f5f95896e4b3562875))
* **extract:** hoist [@doc-wrapped](https://github.com/doc-wrapped) funcdefs so islands keep the return ([168e7ee](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/168e7ee9067be96db86e335430927e08170ec46f))
* **oracle:** canvas import stub returns false, not 0 (i64 BigInt boundary) ([89c01b1](https://github.com/GroupTherapyOrg/PlutoIslands.jl/commit/89c01b19794ea88612c469ff14ee95200f5af26f))
