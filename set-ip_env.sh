#!/usr/bin/env bash
# Lab environment; supply login credentials separately through your environment.
# Load with: source ./set-ip_env.sh
export SH1=3.129.243.95
export SH1_PRIV=10.0.78.183
export MC1=77.113.29.139
export MC1_PRIV=10.0.73.248
export IDX1=3.15.194.127
export IDX1_PRIV=10.0.94.55
export IDX2=3.129.87.15
export IDX2_PRIV=10.0.114.152
export UF1=3.14.5.56
export UF1_PRIV=10.0.74.193
export LAB_SERVERS=3.129.243.95,77.113.29.139,3.15.194.127,3.129.87.15
export LAB_UF_SERVERS=3.14.5.56
export ADMIN_USER=admin
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
export LOGIN_USER=sccStudent
export LOGIN_PASSWORD="${LOGIN_PASSWORD:-}"
export SSHPASS="${SSHPASS:-}"
export LAB_SERVER_FILE=/home/jimy/Downloads/new_lab_server.md
