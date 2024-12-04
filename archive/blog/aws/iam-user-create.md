---
title: IAM User 생성
type: blog
date: 2024-12-02
tags:
  - aws
  - terraform
summary: ""
weight: 2
---

이전 장에서 만든 admin profile 로 추가 사용자를 만들 수 있습니다.

```hcl
# provider.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "admin"
}

variable "account_id" {
  type        = string
  description = "AWS 계정 ID"
}

variable "identity_store_id" {
  type        = string
  description = "AWS IAM Identity Center의 Identity Store ID"
}

variable "identity_center_arn" {
  type        = string
  description = "AWS IAM Identity Center의 Instance ARN"
}

```

```shell
terraform init
```

사진

https://registry.terraform.io/providers/hashicorp/aws/latest/docs
