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
}

###############################################################################
# S3
###############################################################################

resource "aws_s3_bucket" "lambda-bucket" {
  bucket = "random-lambda-bucket-name"
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
  filename      = "./files/lambda_python.zip"
  function_name = "lambda_python"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

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
