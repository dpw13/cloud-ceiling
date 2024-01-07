#!/bin/sh

export MODELSIM_BASE=/opt/lscc/iCEcube2.2020.12/modeltech
export MODELSIM=$MODELSIM_BASE/modelsim.ini
export PATH=$PATH:$MODELSIM_BASE/linuxloem
export LM_LICENSE_FILE=/opt/lattice_icecube2.dat

export PKG_CONFIG_SYSROOT_DIR=/home/dwagner/Documents/sysroots/beaglebone
export PATH=$PATH:/home/dwagner/x-tools/arm-unknown-linux-gnueabihf/bin