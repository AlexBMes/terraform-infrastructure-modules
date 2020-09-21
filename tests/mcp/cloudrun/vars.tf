variable gcp_cloudrun_yml {
  description = "path to YAML file containing congifuation for GAE Applications/Services"
  type = string
  default = "resources/gcp_cloudrun.yml"
}

variable user_project_config_yml {
  type = string
  default = "resources/project.yml"
}
