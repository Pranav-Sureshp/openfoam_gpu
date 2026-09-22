## Summary: Building OpenFOAM v2606 (openfoam-ecse, feature-gpu) on MI355X (ROCm 7.14)

Building the `feature-gpu` branch against AMD Instinct MI355X (CDNA4, `gfx950`) with ROCm 7.14 / gcc 9 / OpenMPI surfaced several issues, all fixed. Summary below in case others hit the same on similar AMD/ROCm environments.

### Environment
- ROCm 7.14 (`amdclang++`), gcc/9, OpenMPI (gcc/9.3/4.0.4)
- `WM_COMPILER=Amd-gpu`, `WM_COMPILER_TYPE=system`, `WM_MPLIB=SYSTEMOPENMPI`
- Target: MI355X = CDNA4 = `gfx950`

---

### 1. `wmake` bootstrap tools fail — `make: clang: No such file or directory`

**Cause:** `wmake/rules/General/Amd-gpu/c` (the plain-C compiler rule, used to build wmake's own internal tools like `lemon`) hardcodes the bare compiler name `clang`, which doesn't exist on `PATH` in this environment — only `amdclang`/`amdclang++` under the ROCm install tree.

**Fix:**
```bash
sed -i 's/\bclang\b/amdclang/' "$WM_PROJECT_DIR/wmake/rules/General/Amd-gpu/c"
sed -i 's/\bclang\b/amdclang/' "$WM_PROJECT_DIR/wmake/rules/General/Clang/c"
```
Note: the C++ rule (`wmake/rules/General/Amd-gpu/c++`) already correctly used `amdclang++` — only the plain-C rule had the bug.

### 2. GPU target architecture

MI355X = `gfx950`. `wmake/rules/General/Amd-gpu/c++` reads this from an env var (not hardcoded, unlike the NVIDIA rule's `cc90` issue on a separate build):
```bash
export ROCM_GPU=gfx950
```



### 3. ThirdParty builds (KAHIP, ADIOS) fail via cmake — `GLIBCXX_3.4.29 not found`

**Cause:** `gcc/9` module prepends its own (older) `lib64` to `LD_LIBRARY_PATH`, shadowing the system's newer `libstdc++.so.6`. `/usr/bin/cmake` was built against a newer GLIBCXX/CXXABI than `gcc/9`'s bundled `libstdc++` provides.

**Fix:** prepend the system lib path so the newer `libstdc++` resolves first (confirmed via `strings /usr/lib64/libstdc++.so.6 | grep GLIBCXX_3.4.29` that the needed symbol version is present system-side):
```bash
export LD_LIBRARY_PATH="/usr/lib64:${LD_LIBRARY_PATH}"
./makeKAHIP
./makeADIOS
```
Confirmed this reordering doesn't break the main OpenFOAM build afterward (`ldd $FOAM_LIBBIN/libOpenFOAM.so` clean of "not found" entries).

---

### Net changes to a stock `feature-gpu` checkout
- `wmake/rules/General/Amd-gpu/c`: `clang` → `amdclang`
- Env: `ROCM_GPU=gfx950`, `LD_LIBRARY_PATH` prefixed with `/usr/lib64` during ThirdParty (KAHIP/ADIOS) builds only
