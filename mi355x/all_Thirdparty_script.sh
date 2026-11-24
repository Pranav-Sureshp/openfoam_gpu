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
echo "WM_THIRD_PARTY_DIR = ${WM_THIRD_PARTY_DIR}"


cd "${WM_THIRD_PARTY_DIR}"

# Check system compatibility

#./Allwmake -j  -s -q -l  2>&1 | tee  ThirdParty_build_${SLURM_JOB_ID}.log

./makeSCOTCH  2>&1 | tee   makeScotch.log
./makeUMPIRE  2>&1 | tee   makeUmpire.log

echo "=== Build finished ==="


