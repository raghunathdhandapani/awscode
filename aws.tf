provider "aws" {
  region  = "ap-south-1"
  profile = "raghunathd"
}


resource "tls_private_key" "mykeys" {
  algorithm   = "RSA"
}


resource "aws_key_pair" "myawskeypair" {
  key_name   = "mykey1122"
  public_key = tls_private_key.mykeys.public_key_openssh
}

resource "aws_security_group" "myawssggroup" {
  name        = "sgraghu"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
  name   = "name"
  values = ["amzn2-ami-hvm*"]
 }
}

resource "aws_instance" "webinstance" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  key_name = "mykey1122"
  security_groups = [aws_security_group.myawssggroup.name]

  tags = {
    Name = "HelloWorld"
  }
  depends_on = [aws_security_group.myawssggroup]
}


resource "aws_ebs_volume" "myvolume" {
  availability_zone = aws_instance.webinstance.availability_zone
  size              = 1
  depends_on = [aws_instance.webinstance]
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.myvolume.id
  instance_id = aws_instance.webinstance.id
  force_detach = true
  depends_on = [aws_ebs_volume.myvolume]
}


resource "null_resource" "mountfs" {

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykeys.private_key_pem
    host     = aws_instance.webinstance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo mkfs.ext4 ${aws_volume_attachment.ebs_att.device_name}",
      "sudo mount ${aws_volume_attachment.ebs_att.device_name} /var/www/html",
      "sudo rm -rvf /var/www/html/*",
      "sudo git clone https://github.com/raghunathdhandapani/aws.git /var/www/html/"
    ]
}
  depends_on = [aws_volume_attachment.ebs_att]
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "raghud1762020"
  acl    = "private"
}

resource "aws_s3_bucket_object" "mybucket_object" {
  bucket = "raghud1762020"
  key    = "vanakkam.jpg"
  source = "vanakkam.jpg"
  acl    = "public-read"
  content_type = "image/jpeg"
  depends_on = [aws_s3_bucket.mybucket]
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "My origin_access_identity"
  depends_on = [aws_s3_bucket_object.mybucket_object]
}

locals {
  s3_origin_id = "raghuS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [aws_cloudfront_origin_access_identity.origin_access_identity]
  enabled = true

  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfronturl" {
    value = aws_cloudfront_distribution.s3_distribution.domain_name
}

resource "null_resource" "update_website" {
  depends_on = [aws_cloudfront_distribution.s3_distribution]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykeys.private_key_pem
    host     = aws_instance.webinstance.public_ip
  }

  provisioner "remote-exec" {
    inline  = [ 	"sudo su << EOF",
            "echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.mybucket_object.key}' />;\" >> /var/www/html/index.php",
            "EOF"
			]
  }
}


resource "null_resource" "launch_website" {
  depends_on = [null_resource.update_website]
  provisioner "local-exec" {
    command = "start chrome ${aws_instance.webinstance.public_ip}/index.php"
  }
}
