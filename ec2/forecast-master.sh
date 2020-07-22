#!/bin/bash
# Script to invoke all forecast ec2 processes

## facebook data update
/usr/lib/R/bin/Rscript './fb_db_update.R' >> './fb_db_update.log' 2>&1
