# SNS topic for CloudCart infrastructure alerts
resource "aws_sns_topic" "cloudcart_alerts" {
  name = "cloudcart-infrastructure-alerts"

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Infrastructure-Alerts"
    }
  )
}

resource "aws_sns_topic_subscription" "cloudcart_alerts_email" {
  topic_arn = aws_sns_topic.cloudcart_alerts.arn
  protocol  = "email"
  endpoint  = "adotbelcher@gmail.com"
}
