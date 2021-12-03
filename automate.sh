#!/bin/bash
aws configure
git clone https://github.com/AmeyShahane/social_distancing_violation_detection.git
cd social_distancing_violation_detection
terraform init
terraform apply
chmod u+x test.sh
sed -i -e 's/\r$//' test.sh
read -p "Press enter to continue"
./test.sh
