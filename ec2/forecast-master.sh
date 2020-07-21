#!/bin/bash
# Script to invoke all forecast ec2 processes

cd /home/rstudio/forecast/
/usr/lib/R/bin/Rscript 'ec2/fb_db_update.R' >> 'ec2/fb_db_update.log' 2>&1

/usr/local/aws-cli/v2/current/bin/aws lambda invoke --function-name stop-ec2 response.json