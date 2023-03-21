# Salt provisioner

This terraform module aims to implement the salt provisioning operations.

The provisioning has 2 different modes.

1. Normal execution: This execution will keep the terraform process up and running until the end of the whole salt execution (positive or negative outcome). It will print the logs in the console.

