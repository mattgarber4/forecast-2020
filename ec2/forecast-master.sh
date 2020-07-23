#!/bin/bash
# Script to invoke all forecast ec2 processes

## facebook data update
/usr/lib/R/bin/Rscript './ec2/fb_db_update.R' >> './ec2/fb_db_update.log' 2>&1
