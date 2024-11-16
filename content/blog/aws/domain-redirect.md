---
title: Domain Redirect
type: blog
date: 2024-11-01
tags:
  - aws
  - ec2
  - alb
summary: "기존에 운영 중이던 *.sample.io 도메인을 *.sample.com으로 안전하게 전환하기 위한 리다이렉션 설정 방법을 소개합니다. AWS Route 53과 Application Load Balancer(ALB)를 활용하여 도메인 리다이렉션을 구성하고, 사용자 경험에 영향을 주지 않으면서 도메인을 마이그레이션하는 전체 과정을 상세히 설명합니다. 특히 여러 서브도메인이 있는 서비스에서 ALB를 활용한 도메인 리다이렉션 구성 방법과 실제 적용 사례를 다룹니다."
---

## 문제

`*.sample.io` 에서 운영 중인 서비스를 `*.sample.com` 으로 리다이렉션 구성하고 추후 `*.sample.io` 를 제거하는 과정이 필요했습니다.

[Route 53에서 도메인을 다른 도메인으로 리디렉션](https://repost.aws/ko/knowledge-center/route-53-redirect-to-another-domain)

- Amazon S3와 Amazon CloudFront를 사용한 도메인 리디렉션
- Application Load Balancer를 사용한 도메인 리디렉션
- Amazon CloudFront 함수를 사용한 도메인 리디렉션

위의 세가지 방법이 제시되었는데, 현재 운영중인 서비스는 도메인이 Application Load Balancer를 가리키고 있어 두번째 방법으로 진행하려고 합니다.

위 문서를 참조하면 가능한 이 방법이 가장 좋다고 안내되어 있습니다.

> **참고:** Amazon Simple Storage Service(S3) 대신 Application Load Balancer를 사용하여 도메인을 구성하는 것이 가장 좋습니다.

## 해결 과정

EC2 > 로드 밸런서

해당 화면에서 운영중인 로드 밸런서 목록을 확인할 수 있다. 여기서는 총 세개의 ALB를 사용중입니다.

- sample-client-admin-alb
- sample-client-alb
- sample-application-alb

해당 ALB들은 Route 53 에서 A 레코드로 설정되어 있어, `*.sample.io` 도메인에서 해당 ALB로 전송되고 있습니다. 관련 설정은 아래 문서에 자세히 나와있으므로 생략하겠습니다.

[Application Load Balancer를 사용하여 한 도메인을 다른 도메인으로 리디렉션](https://repost.aws/ko/knowledge-center/elb-redirect-to-another-domain-with-alb)

문서에서 주의할 점은 sub-domain에 관한 설정이 생략되어있는데요, 현재 상황에서는 각 sub-domain 별로 각각의 ALB에 라우팅 되기 때문에 Redirect 설정 또한 각각 설정해야 합니다.

## 테스트

이러한 설정이 되었는지 운영에 반영하기 전에 테스트할 방법을 생각해 보았지만, 별도 구성없이 테스트할 방법은 없는 것 같습니다. 따라서 임시로 ALB를 구성하여 특정 URL로의 리다이렉트를 테스트 해보려고 합니다.

#### 테스트 순서

1. 먼저 ALB에 연결시킬 target group(redirect-test-tg)을생성합니다. 해당 타겟그룹은 인스턴스 대상으로 생성하되, 인스턴스를 지정하지 않고 설정을 완료시킵니다.
2. ALB(redirect-test-alb)를 생성하여 방금 생성한 target group을 대상으로 선택합니다.
3. Route 53에서 해당 ALB를 A 레코드로 등록시킵니다.
   - 예를 들어 `test.sample.io` 로 연결한뒤 사이트에 접근한다면, `503 Service Temporarily Unavailable` 페이지가 나옵니다. 이는 target group에 인스턴스가 없어 표시되는 화면으로 정상적으로 등록되었음을 확인할 수 있습니다.
4. ALB(redirect-test-alb)에서 '해결과정' 문서에 나와있는대로 Redirect 리스너 규칙을 추가합니다.
   - 여기서 저는 `test.sample.io` → `blog.moseoh.com` 제 블로그로 Redirect 설정하였습니다.
5. 마지막으로 Redirect 설정을 해당 ALB에 추가하여 Redirect가 잘 수행되는지 확인합니다.
   - `test.sample.io` → `blog.moseoh.com`
   - `test.sample.io/docs` → `blog.moseoh.com/docs`
   - 명령어로 확인 `curl -Iv` [`http://test.sample.io`](http://test.sample.io)` -L`

#### 테스트용 리소스 삭제 순서

1. Route 53 > 호스팅 영역 > sample.io `test.sample.io` 삭제
2. EC2 > 로드 밸런서> redirect-test-alb 삭제
3. EC2 > 대상 그룹 > redirect-test-tg 삭제

테스트가 성공적으로 마무리 되었다면, 이제 운영 환경에 그대로 적용하면 될 것 같습니다.
