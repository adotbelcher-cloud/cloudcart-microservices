# Service Connect namespace used for communication between CloudCart services
resource "aws_service_discovery_http_namespace" "cloudcart" {
  name = "cloudcart"

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Service-Connect-Namespace"
    }
  )
}