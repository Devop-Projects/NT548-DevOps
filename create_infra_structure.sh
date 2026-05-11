#!/usr/bin/env bash

set -e

echo "🚀 Creating Terraform infrastructure structure..."

# Helper: create directory if not exists
create_dir() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
    echo "📁 Created directory: $1"
  else
    echo "✔ Directory exists: $1"
  fi
}

# Helper: create file if not exists
create_file() {
  if [ ! -f "$1" ]; then
    touch "$1"
    echo "📄 Created file: $1"
  else
    echo "✔ File exists: $1"
  fi
}

# ─────────────────────────────
# ROOT
# ─────────────────────────────
create_dir infrastructure
create_file infrastructure/README.md
create_file infrastructure/.gitignore

# Add .gitignore content if empty
if [ ! -s infrastructure/.gitignore ]; then
cat <<EOF > infrastructure/.gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
EOF
fi

# ─────────────────────────────
# BOOTSTRAP
# ─────────────────────────────
create_dir infrastructure/bootstrap
create_file infrastructure/bootstrap/main.tf
create_file infrastructure/bootstrap/variables.tf
create_file infrastructure/bootstrap/outputs.tf

# ─────────────────────────────
# MODULES
# ─────────────────────────────
create_dir infrastructure/modules

for module in network eks rds; do
  create_dir infrastructure/modules/$module
  create_file infrastructure/modules/$module/main.tf
  create_file infrastructure/modules/$module/variables.tf
  create_file infrastructure/modules/$module/outputs.tf
  create_file infrastructure/modules/$module/README.md
done

# ─────────────────────────────
# ENVS
# ─────────────────────────────
create_dir infrastructure/envs

for env in dev staging prod; do
  create_dir infrastructure/envs/$env
  create_file infrastructure/envs/$env/main.tf
  create_file infrastructure/envs/$env/variables.tf
  create_file infrastructure/envs/$env/terraform.tfvars
  create_file infrastructure/envs/$env/backend.tf
  create_file infrastructure/envs/$env/outputs.tf
done

# ─────────────────────────────
# SCRIPTS
# ─────────────────────────────
create_dir infrastructure/scripts

create_file infrastructure/scripts/lint.sh
create_file infrastructure/scripts/apply.sh
create_file infrastructure/scripts/destroy.sh

# Make scripts executable
chmod +x infrastructure/scripts/*.sh

echo "✅ Done! Terraform structure ready."