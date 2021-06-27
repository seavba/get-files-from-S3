data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com","s3.amazonaws.com","lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "api_instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy  = data.aws_iam_policy_document.instance_assume_role_policy.json
  managed_policy_arns = [aws_iam_policy.ec2_policy.arn, aws_iam_policy.s3_policy.arn]
}

resource "aws_iam_role_policy_attachment" "lambda_role_policies" {
  role       = aws_iam_role.lambda_role.name
  count      = "${length(var.iam_policy_arn)}"
  policy_arn = "${var.iam_policy_arn[count.index]}"
}

resource "aws_iam_policy" "ec2_policy" {
  name = "policy-618033"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:DescribeNetworkInterfaces","ec2:CreateNetworkInterface","ec2:DeleteNetworkInterface","ec2:DescribeInstances","ec2:AttachNetworkInterface"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "s3_policy" {
  name = "pol-s3-b"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:*","s3-object-lambda:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "api_s3_policy" {
  name = "api-gateway-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::random-lambda-bucket-name/*"
      },
    ]
  })
}

resource "aws_iam_role" "api-gateway-upload-to-s3_role" {
  name = "api-gateway-upload-to-s3"
  assume_role_policy  = data.aws_iam_policy_document.api_instance_assume_role_policy.json
  managed_policy_arns = [aws_iam_policy.api_s3_policy.arn]
}

resource "aws_iam_role_policy_attachment" "api_role_policy" {
  role       = aws_iam_role.api-gateway-upload-to-s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
