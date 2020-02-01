#!/bin/bash
PROJ_DIR="$(ls /proj/ | tail -1)"
sudo /proj/${PROJ_DIR}/kube-config/kube-join.sh
