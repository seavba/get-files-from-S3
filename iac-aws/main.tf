locals {
  aws_profile = "test"
  tags = {
    Owner       = "sergio"
    Environment = "devops"
    Application = "API"
  }
}


###############################################################################
# PROVIDER
###############################################################################

provider "aws" {
  region = "${var.aws_region}"
  profile = local.aws_profile
  access_key = "AKIAREAFFMA723FFUNJA"
  secret_key = "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"
}

###############################################################################
# S3
###############################################################################

resource "aws_s3_bucket" "lambda-bucket" {
  bucket = "${var.bucket_name}"
}

resource "aws_s3_bucket_object" "folders" {
    for_each = toset(["lists/", "zip/","images/"])
    bucket = "${aws_s3_bucket.lambda-bucket.id}"
    key    = each.key
    source = "/dev/null"
}

###############################################################################
# EFS
###############################################################################

resource "aws_efs_file_system" "lambda_efs" {
 creation_token = "efs-lambda_efs"
 performance_mode = "generalPurpose"
 throughput_mode = "bursting"
}

resource "aws_efs_mount_target" "lambda_efs_mount" {
  count = "${length(aws_subnet.private_lambda.*.id)}"
  file_system_id  = "${aws_efs_file_system.lambda_efs.id}"
  subnet_id = "${element(aws_subnet.private_lambda.*.id, count.index)}"
  security_groups = ["${aws_security_group.lamda-efs-sg.id}"]
}

resource "aws_efs_access_point" "lambda_efs_ap" {
  file_system_id = aws_efs_file_system.lambda_efs.id


  posix_user {
    gid = "${var.uid}"
    uid = "${var.uid}"
  }

  root_directory {
    path = "/compress"
    creation_info {
      owner_gid   = "${var.uid}"
      owner_uid   = "${var.uid}"
      permissions = "${var.permissions}"
    }
  }
}


###############################################################################
# LAMBDA
###############################################################################

resource "aws_lambda_permission" "lambda_allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_python.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.lambda-bucket.arn
}

resource "aws_lambda_function" "lambda_python" {
  filename      = "./files/lambda_function.zip"
  function_name = "lambda_python"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_python.lambda_handler"

  runtime = "python3.7"

  file_system_config {
    arn = aws_efs_access_point.lambda_efs_ap.arn
    local_mount_path = "/mnt/compress"
  }

  vpc_config {
    subnet_ids = aws_subnet.private_lambda.*.id
    security_group_ids = ["${aws_security_group.lamda-efs-sg.id}"]
  }

  depends_on = [aws_efs_mount_target.lambda_efs_mount]
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.lambda-bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_python.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "lists/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.lambda_allow_bucket]
}

###############################################################################
# API
###############################################################################

resource "aws_api_gateway_rest_api" "s3_api" {
 name = "s3.uploader.com"
}

resource "aws_api_gateway_resource" "s3_api_folder_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.s3_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.s3_api.root_resource_id}"
  path_part   = "{folder}"
  depends_on = [aws_api_gateway_rest_api.s3_api]
}

resource "aws_api_gateway_resource" "s3_api_lists_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.s3_api.id}"
  parent_id   = "${aws_api_gateway_resource.s3_api_folder_resource.id}"
  path_part   = "lists"
  depends_on = [aws_api_gateway_resource.s3_api_folder_resource]
}

resource "aws_api_gateway_resource" "s3_api_object_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.s3_api.id}"
  parent_id   = "${aws_api_gateway_resource.s3_api_lists_resource.id}"
  path_part   = "{object}"
  depends_on = [aws_api_gateway_resource.s3_api_lists_resource]
}

resource "aws_api_gateway_method" "s3_api_method" {
  rest_api_id   = "${aws_api_gateway_rest_api.s3_api.id}"
  resource_id   = "${aws_api_gateway_resource.s3_api_object_resource.id}"
  http_method   = "PUT"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.object" = true,
    "method.request.path.folder" = true
   }
  depends_on = [aws_api_gateway_resource.s3_api_object_resource]
}

resource "aws_api_gateway_integration" "s3_api_method_integration" {
  rest_api_id   = "${aws_api_gateway_rest_api.s3_api.id}"
  resource_id   = "${aws_api_gateway_resource.s3_api_object_resource.id}"
  http_method = "${aws_api_gateway_method.s3_api_method.http_method}"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.aws_region}:s3:path/{bucket}/lists/{key}"
  integration_http_method = "PUT"
  credentials = "arn:aws:iam::077320249407:role/api-gateway-upload-to-s3"

  request_parameters = {
    "integration.request.path.bucket" = "method.request.path.folder",
    "integration.request.path.key" = "method.request.path.object"
  }
  depends_on = [aws_api_gateway_method.s3_api_method]
}

resource "aws_api_gateway_method_response" "s3_api_response_200" {
  rest_api_id = "${aws_api_gateway_rest_api.s3_api.id}"
  resource_id = "${aws_api_gateway_resource.s3_api_object_resource.id}"
  http_method = aws_api_gateway_method.s3_api_method.http_method
  status_code = "200"
  depends_on = [aws_api_gateway_integration.s3_api_method_integration]
}

resource "aws_api_gateway_integration_response" "s3_api_integration_response" {
  rest_api_id = "${aws_api_gateway_rest_api.s3_api.id}"
  resource_id = "${aws_api_gateway_resource.s3_api_object_resource.id}"
  http_method = aws_api_gateway_method.s3_api_method.http_method
  status_code = aws_api_gateway_method_response.s3_api_response_200.status_code
  depends_on = [aws_api_gateway_method_response.s3_api_response_200]
}

resource "aws_api_gateway_deployment" "s3_api_deployment" {
  rest_api_id = "${aws_api_gateway_rest_api.s3_api.id}"
  stage_name = "v1"

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_integration_response.s3_api_integration_response]
}
