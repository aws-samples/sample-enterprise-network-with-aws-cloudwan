{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ReadWrite",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:ListBucketVersions"
      ],
      "Resource": [
        "arn:aws:s3:::*/*",
        "arn:aws:s3:::*"
      ]
    },
    {
      "Sid": "AllowAmazonLinuxRepos",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::amazonlinux-2-repos-${aws_region}/*",
        "arn:aws:s3:::amazonlinux-2-repos-${aws_region}",
        "arn:aws:s3:::amazonlinux.${aws_region}.amazonaws.com/*",
        "arn:aws:s3:::amazonlinux.${aws_region}.amazonaws.com",
        "arn:aws:s3:::packages.${aws_region}.amazonaws.com/*",
        "arn:aws:s3:::packages.${aws_region}.amazonaws.com",
        "arn:aws:s3:::repo.${aws_region}.amazonaws.com/*",
        "arn:aws:s3:::repo.${aws_region}.amazonaws.com"
      ]
    },
    {
      "Sid": "AllowSSMAccess",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::aws-ssm-${aws_region}/*",
        "arn:aws:s3:::aws-windows-downloads-${aws_region}/*",
        "arn:aws:s3:::amazon-ssm-${aws_region}/*",
        "arn:aws:s3:::amazon-ssm-packages-${aws_region}/*",
        "arn:aws:s3:::${aws_region}-birdwatcher-prod/*",
        "arn:aws:s3:::patch-baseline-snapshot-${aws_region}/*"
      ]
    },
    {
      "Sid": "AllowCloudWatchLogs",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::aws-logs-*/*"
      ]
    }
  ]
}
