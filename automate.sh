#!/bin/bash
aws configure
terraform init
terraform apply
chmod u+x test.sh
sed -i -e 's/\r$//' test.sh
read -p "Press enter to run the program"
./test.sh
read -p "Press enter to destroy resources"
terraform destroy
