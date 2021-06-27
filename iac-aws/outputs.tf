output "api_url" {
  value = "curl -X PUT -H 'Accept:application/json' -H 'Content-Type:application/octet-stream' --data-binary @files/testapi.json ${aws_api_gateway_deployment.s3_api_deployment.invoke_url}/${var.bucket_name}/lists/testapi.json"
}
