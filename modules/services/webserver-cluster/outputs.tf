output "clb_dns_name" {
    value       = aws_elb.webserver_loadbalancer.dns_name
    description = "The domain name of the load balancer"
}
