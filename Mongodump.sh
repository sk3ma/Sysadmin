#!/usr/bin/env bash

##############################################################################################
# This script performs a MongoDB backup by creating a dump of the database on the localhost. #
# It creates a tar archive of the dump, and uploads the tar archive to an AWS S3 bucket.     #
##############################################################################################

# Declaring variables.
USERID=$(id -u)
HOST=localhost
DBASE=webapp
DEST=/tmp/backup
TIME=$(date +%F)
BCKP=${DEST}/${DBNAME}-${TIME}.tgz
LINK=https://s3.amazonaws.com/${BUCKET}/${DATE}.tgz
BCKT=librarian

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
  echo -e "\e[31;1;3;5m[✗] You must be root, exiting\e[m"
  exit 1
fi

# AWS installation.
awscli() {
  echo -e "\e[32;1;3m[INFO] Installing package\e[m"
  apt update
  apt install unzip -y
  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm -f awscliv2.zip
  echo -e "\e[33;1;3m[INFO] Finished, package installed.\e[m"
}

# Confirming existence.
if ! [[ command -v aws &> /dev/null ]]; then
  awscli
fi

# Backup directory.
if [[ ! -d "${DEST}" ]]; then
  mkdir -vp "${DEST}"
fi

# Display action.
echo -e "\e[32;1;3m[INFO] Dumping: ${HOST}/${DBASE} to S3: ${BCKT} with Date: ${TIME}""\e[m"

# Database backup.
mongodump -h ${HOST} -d ${DBASE} -o ${DEST}

# Create archive.
tar -cvf ${BCKP} ${TIME}.tgz -C ${DEST} .

# S3 upload.
aws s3 cp ${BCKP} s3://${BCKT}/ --storage-class STANDARD_IA

# Remove archive.
rm -vf ${BCKP}

# Remove directory.
rm -rvf ${DEST}

# End status.
echo -e "\e[32;1;3;5m[✓] Backup available at ${LINK}\e[m"
