# Changelog

## [0.1.1](https://github.com/GroupTherapyOrg/Snapshot.jl/compare/v0.1.0...v0.1.1) (2026-07-13)


### Features

* bond marshalling via WasmTarget.Bridge — String/NamedTuple/Vector/struct bonds ([122f4d4](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/122f4d48ffd65f6c1e032a6e3d4fd64bfd3e0577))
* expand coalesced image-stream commands in the canvas oracle ([2d80fab](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/2d80fab6c926e7b1bf3a41e6a0f9b044738aadb4))
* **export:** auto-generate complete Pluto→DaisyUI CSS from source + pure-DaisyUI everywhere ([d763049](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/d763049fa1ccc7c77faa9607ccb3db153f12ed4e))
* **export:** base-level SSR of tree/object outputs — value always shown, 1-1 Pluto ([931331b](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/931331b657b0c5986e3e580d797677c8238a433a))
* **export:** emit &lt;name&gt;.fragment.html on therapy=true for native-inline embedding ([86b93cc](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/86b93cc41abdbb81bb8c382d5d5445da25bbf023))
* featured corpus draws with WasmMakie — every plot and image is a Figure ([7581807](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/7581807865bc526363b5ccafa5aa55907b922c26))
* finalize Snapshot on the WasmTarget 0.5 stack ([fc5d6ea](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/fc5d6eabe06c91a521e69989cc159b5aedf1a12d))
* full HTML-widget introspection — select/text/color/date bonds ([a07b7f7](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/a07b7f742800cb177b5e40be55b126e79170362d))
* html-wrapper bodies + raw-HTML widget introspection ([e9ed6f6](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/e9ed6f6f6aedfac3ce64a12808dbf417cac22a9a))
* low-hanging-fruit batch — toplevel exprs, tuple trees, transform_value, BigInt, stacktrace cells ([d6760f8](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/d6760f8825961b48f6a83ba2650415215b2ad5f1))
* repr-flavoured plain bodies + full bridge-era re-export — 17/67 groups ship ([ef9426e](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/ef9426efdefe2bc5cd12c4a982e035ef5180d0cf))
* **shim:** warn LOUDLY when an island render throws at runtime (never silent-blank) ([b802a83](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/b802a8323ff6e708c8e5605d5b14a871d9803c93))
* **themes:** classic-light / classic-dark — 1:1 Pluto palettes as DaisyUI themes ([47155df](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/47155df1fecbc6ed30632c5be31a9e2576c032fb))
* tree-viewer bodies via the bridge read-side + notebook-env sandbox ([b4e508d](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/b4e508d85b077506012d684e2d281172f14444ae))
* wasm-failure diagnostic cards — structured WasmTarget diagnostics in the fallback UI ([0aecca0](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/0aecca01767745dd8cf84ae847db93339b68a10a))
* wasm-failure diagnostic cards (structured WasmTarget diagnostics + AI context) ([f04484d](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/f04484d928ad02d695936e16a5118b28bd3bea2c))


### Bug Fixes

* admit canvas cells through imported compilation ([453903f](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/453903f570dc6d7544ba8ffecd5a2be1064da272))
* **ci:** docs export oracle needs node 22 (WasmGC default) — node 20 nuked all islands ([55f4ddf](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/55f4ddf8eee8b7771980b16030c4aa1e888529c7))
* **ci:** unified docs matrix reads ONE notebook list (no slug mismatch) ([1482252](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/1482252e2d8e99ab889003c70356b4f427b256e8))
* compile dynamic notebook worlds at latest age ([#25](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/25)) ([3cb95b4](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/3cb95b4f91579ba84e576ebd32fc15eb2388a362))
* **docs:** notebook cards full-load (target=_self) so inline islands hydrate ([3e8e85e](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/3e8e85eb129fc6c40729199f68ae7ee42e80ee39))
* **export/shim:** show the WASM-compile fallback warning in the lean export ([9126ee6](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/9126ee67045cd5c92a67436da1ff0fc15d9897e0))
* **export:** bound baked tree SSR — node budget + don't bake large island bodies ([75cef18](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/75cef18c808c429696c1dec07b97bba466ea5dda))
* **export:** contain Pluto margin-widgets (no h-overflow) + Pluto-1-1 ToC in both contexts ([05a722a](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/05a722a6fa180c2acdfd9cd77612c0ff77a95c22))
* exported initial state matches widget defaults (synthetic-initial groups) ([4f73cdf](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/4f73cdf4f86582f73c9426f5f95896e4b3562875))
* **export:** encode date/time bond inputs in the lean wiring (was silently blanking the cell) ([9a5edb0](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/9a5edb063631d7b2e81b2bb03032c3d12f666b74))
* **export:** run Pluto cell &lt;script&gt;s in Pluto's scope model → slider show_value works ([477482f](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/477482f405954d95ce023c70baf24995c9a2af96))
* **extract:** hoist [@doc-wrapped](https://github.com/doc-wrapped) funcdefs so islands keep the return ([168e7ee](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/168e7ee9067be96db86e335430927e08170ec46f))
* **oracle:** canvas import stub returns false, not 0 (i64 BigInt boundary) ([89c01b1](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/89c01b19794ea88612c469ff14ee95200f5af26f))
* **pluto-css:** scope error.css pre/code → no red bar on code cells; map hardcoded colors ([0a117a0](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/0a117a0a17defa91909540d5c4e5bfb8ae766abd))
* restore featured notebook canvas coverage ([#24](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/24)) ([31f5e40](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/31f5e409a603b0f2775c945d59d7b40cf39f6cf8))
* **shim:** decode Float64 bridge bit-pattern back to a float for display ([0beb67f](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/0beb67fbf30a2e2a67f47480f8a77823ff03461c))
* **shim:** robustly decode Float64 bridge bit-patterns (type-branch, don't assume) ([004f6ac](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/004f6ac4746eaae293630022930c4f250ecdb88b))
* unbreak CI vs WasmTarget 0.4 — open compat (&gt;= 0.4) + diag field on exclude_cells failures ([c37b3ba](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/c37b3ba7c736ebe520308b26a59c401da09b3fe5))
* unbreak CI vs WasmTarget 0.4 — open compat (&gt;= 0.4) + diag on exclude_cells failures ([a456f9c](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/a456f9c97cf671aed2defa5463066c801d6c9e01))


### Reverts

* **ci:** restore single-job docs.yml — the unified matrix shipped a broken site ([c8062a1](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/c8062a1b47826f7ebd2b9e3f34c3a8b082a2810c))
* **shim:** restore original bits handling — my display fix broke wasm feeding ([a132860](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/a1328602354ab629769734ec24a59edb8525c1ea))
