# OpenFOAM v2606 GPU build on AMD Instinct MI355X

This repository includes Slurm scripts for building the `feature-gpu` branch of `openfoam-ecse` and a Shercliff benchmark case for the GPU build of `mhdFoam`.

## Repository layout

| Directory | Contents |
| --- | --- |
| [`mi355x/`](mi355x/) | Slurm build jobs, shell scripts, and build notes for MI355X |
| [`Shercliff_mhdFoam_Ha100/`](Shercliff_mhdFoam_Ha100/) | Shercliff magnetohydrodynamics benchmark at Hartmann number 100, using `mhdFoam` |

## Build environment

The build used ROCm 7.14, the `gcc/9` module, and OpenMPI `gcc/9.3/4.0.4`. The MI355X target is CDNA4 (`gfx950`).

Both build scripts source `~/.openfoam_v2606_mi355x_profile`. Set up that profile to load the site modules, configure the following settings, and initialise the OpenFOAM environment. Verify that `WM_PROJECT_DIR` and `WM_THIRD_PARTY_DIR` resolve to the intended OpenFOAM and ThirdParty source trees.

```bash
export WM_COMPILER=Amd-gpu
export WM_COMPILER_TYPE=system
export WM_MPLIB=SYSTEMOPENMPI
export ROCM_GPU=gfx950
```

## Build ThirdParty and OpenFOAM

**Build Umpire before running OpenFOAM's `./Allwmake`.** Umpire is the GPU memory management library. Build it from the ThirdParty directory with `./makeUMPIRE`.

Review the Slurm account and partition in both job scripts for your cluster. Run the following from the repository root. The Slurm jobs invoke their companion scripts from the submission directory.

```bash
cd mi355x
sbatch build_thirdparty_v2606.mi355x
```

The first job invokes `all_Thirdparty_script.sh`, which runs `./makeSCOTCH` followed by `./makeUMPIRE` in `$WM_THIRD_PARTY_DIR`. Wait for the job to finish and check `makeScotch.log` and `makeUmpire.log` in that directory. The commands pipe their output through `tee`, so the job's completion status alone can miss a build failure.

Once Umpire has built successfully, submit the OpenFOAM job from the same `mi355x/` directory.

```bash
sbatch build_v2606.mi355x
```

This job invokes `allwmake_script.sh`, which cleans previous build outputs in `src` and `applications`, runs `foamSystemCheck`, and builds OpenFOAM with `./Allwmake -j -s -q -l` in `$WM_PROJECT_DIR`. Check `OpenFOAM_build_${SLURM_JOB_ID}.log` and `log.foamInstallationTest` there after the job finishes.

### Build fixes for this environment

If the `wmake` bootstrap fails with `make: clang: No such file or directory`, update the plain-C compiler rules. In the reported environment, ROCm provided `amdclang` and `amdclang++`. The AMD GPU C++ rule already used `amdclang++`.

```bash
sed -i 's/\bclang\b/amdclang/' "$WM_PROJECT_DIR/wmake/rules/General/Amd-gpu/c"
sed -i 's/\bclang\b/amdclang/' "$WM_PROJECT_DIR/wmake/rules/General/Clang/c"
```

If you also build KaHIP or ADIOS and CMake reports `GLIBCXX_3.4.29 not found`, check which `libstdc++.so.6` CMake loads. On this system, the GCC 9 module put an older copy ahead of the system library. From the ThirdParty directory, the following commands gave the system library precedence for those builds.

```bash
cd "$WM_THIRD_PARTY_DIR"
LD_LIBRARY_PATH="/usr/lib64:${LD_LIBRARY_PATH}" ./makeKAHIP
LD_LIBRARY_PATH="/usr/lib64:${LD_LIBRARY_PATH}" ./makeADIOS
```

## MI355X runtime configuration

Set `FOAM_MEMORY_POOL` in the shell or Slurm job that launches the solver. The reported MI355X case runs with the managed pool.

```bash
export FOAM_MEMORY_POOL="managed; size=1024; incr=1024"
```

OpenFOAM and Umpire built successfully, but the MI355X run failed with `FOAM_MEMORY_POOL="host; size=1024; incr=1024"`. The host pool had previously worked on MI300A, where it was used to take advantage of shared CPU–GPU memory. The error is consistent with a host–GPU memory accessibility mismatch. A change in newer ROCm versions is suspected. The root cause remains unconfirmed.

In a separate lid-driven cavity benchmark shared by Jony, the MI355X run took roughly **60× as long** as the MI300A run. Managed memory was also reported to perform poorly on MI300A. The cause of the cavity timing gap remains unknown.

## Shercliff benchmark

[`Shercliff_mhdFoam_Ha100/`](Shercliff_mhdFoam_Ha100/) contains the Shercliff example case. Load the GPU-enabled OpenFOAM environment and set `FOAM_MEMORY_POOL` as shown above before launching `mhdFoam` on MI355X.
