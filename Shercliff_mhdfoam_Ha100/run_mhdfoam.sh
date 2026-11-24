#!/bin/bash
# Source the OpenFOAM profile

ulimit -s unlimited

cores=1 
solver=mhdFoam  #epotFoam_isoTh  # cEpotmhdEpotMultiRegionFoam
source ~/.openfoam_v2606_mi355x_profile


module list > log.module_list
env > log.env
rocminfo > log.rocminfo
rocm-smi > log.rocm-smi
rocm-smi --showtopo > log.rocm-smi-topo
hipconfig --full > log.hipconfig 
hipcc --version > log.hipcc


echo "===== ENVIRONMENT ====="
which mpirun
mpirun --version
which mhdFoam
echo "WM_COMPILER=$WM_COMPILER"
echo "WM_OPTIONS=$WM_OPTIONS"
echo "WM_MPLIB=$WM_MPLIB"
echo "ROCM_PATH=$ROCM_PATH"
echo "HIP_PATH=$HIP_PATH"

echo "===== GPU ====="
rocminfo | grep -E 'Name:|Marketing Name:' | head -20

export HIP_VISIBLE_DEVICES=0
export HSA_XNACK=1
blockMesh   2>&1 | tee log.blockMesh_fluid


if [[ ! $cores -eq 1 ]]
then
    decomposePar 2>&1 | tee log.decomposePar

    { time mpirun -np $cores  $solver -parallel; } 2>&1 | tee log.genFoam

    reconstructPar 2>&1 | tee log.reconstructPar
else
    { time $solver; } 2>&1 | tee log.$solver
fi


