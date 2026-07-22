# Changelog

## [0.2.1](https://github.com/GroupTherapyOrg/Snapshot.jl/compare/v0.2.0...v0.2.1) (2026-07-22)


### Bug Fixes

* add portable single-file exports ([#57](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/57)) ([2e24af9](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/2e24af9035c1e5e8040682f105cbdf8f3a2e23ca))

## [0.2.0](https://github.com/GroupTherapyOrg/Snapshot.jl/compare/v0.1.1...v0.2.0) (2026-07-17)


### Features

* add fun notebook themes ([#38](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/38)) ([cc7acb0](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/cc7acb0e9c5a8fb8cc7ca3c1f02ae3be326cefc2))
* configure honest island fallbacks ([#43](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/43)) ([ded0065](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/ded0065860893731991eee45990c9cca187ecf99))
* make lean exports default and theme raw controls ([#50](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/50)) ([cd5c6db](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/cd5c6dbe7b93c371d5f5a6061ed4bec3fae3c922))
* schedule persistent notebook canvas frames ([#33](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/33)) ([e95cfe6](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/e95cfe682d6c379c37f5f83d5fa2e9a4a3716868))


### Bug Fixes

* **ci:** allow prealigned release versions ([#55](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/55)) ([83f25de](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/83f25de1036873dc6b35961b066ad48b3793a8e8))
* **ci:** authorize release pull request checks ([#56](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/56)) ([bd489be](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/bd489be3291e113700f6a123bf667d6801dad0d0))
* deploy committed notebook bundles ([#27](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/27)) ([5c80345](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/5c80345dac4dc22c34658ac9a35d9c77cb5a7ba8))
* disable controls for static fallback groups ([#42](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/42)) ([407ee98](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/407ee983c4121ecaac48da812389f1e229c6aa8e))
* inherit host theme in fragments ([#45](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/45)) ([316c5ac](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/316c5acb1f768fc6a839788e73d9c91fd04fb581))
* initialize notebook fragments after navigation ([#48](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/48)) ([f0932cb](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/f0932cb2cd23781fe6d63fa488b65a16fa968e2d))
* isolate wasm island imports ([ee40f2a](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/ee40f2ad05fd6a84a44537297d35e153f0b29719))
* isolate wasm island imports ([a170a60](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/a170a607777edd51dc47764aedd31fe7e8a03428))
* keep embedded ToC scrolling inside collection ([#46](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/46)) ([cf1fcdb](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/cf1fcdb02f5fa039f3be5b91fc01d26ae1fb01a5))
* marshal Pluto button click counts ([#28](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/28)) ([4193ec2](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/4193ec2a0289c76ba4b6a2043cb6268802b5fde3))
* parse complete notebook cells ([#41](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/41)) ([aaa36aa](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/aaa36aad20bcb7a7b7f26618916bb58de1702f0d))
* preserve fallback controls without reports ([#44](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/44)) ([fa4e95c](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/fa4e95ca8b77bec0e5351138608a6038896cea12))
* preserve Pluto semantics in notebook exports ([#47](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/47)) ([5ebf817](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/5ebf81702934267806d213376f4a769fa898f791))
* preserve unreleased snapshot frame contracts ([#35](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/35)) ([e344b69](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/e344b691de69a021d10f025a13f0b257028fddc5))
* serialize wrapped PlutoUI bonds by logical value ([#30](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/30)) ([348c318](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/348c3187a9ad5ef21dda6a3bed1e5533a022d59f))
* summarize notebook cell errors ([#40](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/40)) ([b500f4e](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/b500f4eed474256da21a898867951819f2b251c0))
* theme wrapped notebook controls ([#52](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/52)) ([ab3b596](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/ab3b5960cbe8806692de9a1d198d91b4d17b91ac))


### Miscellaneous Chores

* harden release automation ([#53](https://github.com/GroupTherapyOrg/Snapshot.jl/issues/53)) ([46bc600](https://github.com/GroupTherapyOrg/Snapshot.jl/commit/46bc6008f970c636b7945acbfea1ce15a692a461))

## [0.1.1](https://github.com/GroupTherapyOrg/Snapshot.jl/releases/tag/v0.1.1) (2026-07-13)


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
