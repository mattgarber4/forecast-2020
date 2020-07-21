#!/bin/bash
# Script to invoke all forecast ec2 processes

cd /home/rstudio/forecast/ec2/
/usr/lib/R/bin/Rscript 'fb_db_update.R' >> 'fb_db_update.log' 2>&1

/usr/local/aws-cli/v2/current/bin/aws lambda invoke --function-name stop-ec2 response.json