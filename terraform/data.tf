# Discover available Availability Zones in the configured AWS region
data "aws_availability_zones" "available" {
  state = "available"
}