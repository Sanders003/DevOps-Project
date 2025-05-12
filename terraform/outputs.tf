output website_url {
  description = "Access your Flask app at this URL"
  value       = "http://${aws_instance.flask_app.public_ip}:8000"
}
