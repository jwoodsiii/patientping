module "state_backend" {
  source = "../modules/tf-state-backend"

  bucket_name = var.tf_state_bucket
  table_name  = var.tf_lock_table
}

module "github_oidc" {
  source = "../modules/tf-github-oidc"

  github_org       = var.github_org
  github_repo      = var.github_repo
  state_bucket_arn = module.state_backend.bucket_arn
  table_arn        = module.state_backend.table_arn
}
