#!/bin/bash
ulimit -s unlimited

source ~/.openfoam_v2606_mi355x_profile

module list > log.module_list
env > log.env
rocminfo > log.rocminfo
rocm-smi > log.rocm-smi
rocm-smi --showtopo > log.rocm-smi-topo


# Number of parallel compile jobs = allocated cpus on this node

echo "=== Building on $(hostname), using ${NPROCS} parallel compile jobs ==="
echo "WM_PROJECT_DIR = ${WM_PROJECT_DIR}"


cd "${WM_PROJECT_DIR}"
wclean all

# Check system compatibility
foamSystemCheck > log.foamSystemCheck

./Allwmake -j  -s -q -l  2>&1 | tee OpenFOAM_build_${SLURM_JOB_ID}.log

echo "=== Build finished ==="

# Verify
foamInstallationTest > log.foamInstallationTest

