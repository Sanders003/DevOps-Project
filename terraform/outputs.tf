output website_url {
  description = "Access your Flask app at this URL"
  value       = "http://${aws_instance.flask_app.public_ip}:8000"
}

output s3bucket {
  description = "Access for s3 bucket only from instance"
  value       = "aws s3 cp s3://${aws_s3_bucket.data_source_bucket.id}/data.txt"
}

output ssh-connect {
  description = "SSH connect line"
  value = "ssh -i project.pem ubuntu@${aws_instance.flask_app.public_ip}"
}