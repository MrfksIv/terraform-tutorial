provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "own"
  region                  = var.region
}

module "webserver_cluster" {
  source        = "../../../modules/services/webserver-cluster"
  cluster_name  = "webserver-stage"
  min_size      = 2
  max_size      = 3
  instance_type = "t2.nano"
}

module "user_creation" {
  source = "../users"
}


// We can define two autoscaling schedules that define how our cluster should scale depending on the time of day
resource "aws_autoscaling_schedule" "scaleout_business_hours" {
  scheduled_action_name   = "scaleout-during-business-hours"
  min_size                = 1
  max_size                = 10
  desired_capacity        = 10
  recurrence              = "0 9 * * *" // at 9a.m everyday

  autoscaling_group_name  = module.webserver_cluster.asg_name
}

resource "aws_autoscaling_schedule" "scalein_at_night" {
  scheduled_action_name   = "scalein-at-night"
  min_size                = 1
  max_size                = 10
  desired_capacity        = 1
  recurrence              = "0 17 * * *" // at 5p.m everyday

  autoscaling_group_name  = module.webserver_cluster.asg_name
}
