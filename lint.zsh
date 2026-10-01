#! /bin/zsh

# This script is used to lint the Ansible playbooks and roles using ansible-lint.
ansible-lint playbooks/deploy.yml
ansible-lint playbooks/reboot.yml
