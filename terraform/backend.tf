terraform {
  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/33420444/terraform/state/gitlab"
    lock_address   = "https://gitlab.com/api/v4/projects/33420444/terraform/state/gitlab/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/33420444/terraform/state/gitlab/lock"
    username       = "TUM-DSE"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = "5"
  }
}
