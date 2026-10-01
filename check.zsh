#! /bin/zsh

# Run Nomadintosh in check mode
ansible-playbook playbooks/deploy.yml --check --diff
