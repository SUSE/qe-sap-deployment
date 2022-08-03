#cloud-config to deploy the admin user in EC2 instances
cloud_final_modules:
- [users-groups,always]
users:
  - name: ${username}
    groups: [ wheel ]
    sudo:
      - "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh-authorized-keys: 
    - ${publickey}
