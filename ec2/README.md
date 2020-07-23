This is the directory for files specific to the EC2 instances running the forecast. The instance is configured to checkout only a subset of the repository to save disk space.

# Steps to add a file to the EC2 instance: #
1. Commit the file to the master branch of the origin repo. 
2. Ensure a pattern matching the file location is included in the file ```ec2/checkout-config.txt```. Patterns are matched in this file the same way that they are in a .gitignore file.

# Steps to add a script to the EC2's daily run: #
1. Ensure that the file is accessible to the instance by following the above steps.
2. Add the command to run the script to the master shell script ```ec2/forecast-master.sh```. Paths are rooted at the repo level. To run an R script, use the following command: ```/usr/lib/R/bin/Rscript path/to/script [>> path/to/log/file]```
