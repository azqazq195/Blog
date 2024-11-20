---
title: Signed Cookie
type: blog
date: 2024-11-02
tags:
  - aws
  - s3
summary: 'AWS S3에서 호스팅되는 콘텐츠에 대한 보안 접근 방법을 소개합니다. Pre-signed URL, Signed URL, Signed Cookie 등 다양한 보안 방식의 특징을 비교하고, 여러 리소스에 대한 효율적인 접근 제어가 필요한 상황에서 CloudFront Signed Cookie를 활용하는 방법을 상세히 설명합니다. 특히 다수의 보안 리소스를 제공해야 하는 웹사이트에서 Signed Cookie를 구현하는 실제 사례를 다룹니다.'
---

## 문제

S3에서 컨텐츠를 제공하는 URL에 있어서 S3의 정적 URL을 숨겨야 한다는 요구사항이 있었습니다. 또한 URL 접근에 대한 보안조치를 요구하였습니다.

S3 URL 보안조치에는 세가지 방법이 존재합니다.

- Pre-signed URL (S3)
  - 단일 S3 객체에 대한 임시 접근
- Signed URL (CloudFront)
  - CloudFront를 통해 특정 리소스에 대한 접근
- Signed Cookie (CloudFront)
  - CloudFront를 통해 여러 리소스에 대해 쿠키를 통해 접근 제어

Pre-signed URL은 클라이언트가 서���를 거치지 않고 S3로 직접 파일을 업로드할 수 있도록 할 때, 자주 사용됩니다. 서버는 클라이언트에게 Pre-signed URL을 생성해 제공하고, 클라이언트는 이
URL을 통해 지정된 시간 동안 S3에 파일을 안전하게 업로드할 수 있습니다.

**::Singed URL과 Cookie의 비교에서는 Signed Cookie를 선택하였습니다.::** Signed URL은 단일 객체에 대한 접근을 허용합니다. 웹사이트에서는 다양한 리소스를 가지고 있는데 매번
Signed URL을 생성해야하는 문제가 발생할 수 있습니다. 반면에 Signed Cookie는 한 번의 쿠키 설정으로여러 리소스에 대한 접근은 허용할 수 있습니다.

추가로 Jira에서는 Blob URL 방식을 사용하는데 Blob URL은 브라우저 세션내에서만 유효한 URL입니다. 기밀성이 극도로 중요한 프로젝트에 적합합니다. Blob URL을 통한 보안은 다음에 다루어 보도록
하겠습니다.

## 테스트

{{% steps %}}

### RSA 키 생성

CloudFront에서 키를 생성해주지는 않으므로 먼저 RSA 키를 일단 생성해줍니다.

```shell
openssl genrsa -out private_key.pem 2048
openssl rsa -in private_key.pem -pubout -out public_key.pem
```

### Public Key 등록

1. CloudFront > 키 관리 > 퍼블릭 키

   방금 생성한 `public_key.pem` 을 등록

1. CloudFront > 키 관리 > 키 그룹

   방금 생성한 퍼블릭 키로 키 그룹을 생성

### S3 생성

운영환경에 적용하기 전에 테스트용 S3를 생성합니다.

- my-test-bucket
- 모든 퍼블릭 액세스 차단
  - CloudFront 만으로 접근할 수 있도록 액세스 차단

### CloudFront 배포

1. OAC 설정 (CloudFront에서만 접근 허용)
2. 뷰어 엑세스 제한 - 키 그룹 지정

대체 도메인을 사용한다면?

1. 대체 도메인 SSL 발급 및 설정
   - ACM us-east-1 에서 발급 받은 인증서만 적용 가능
   - sample.com, \*.sample.com (혹은 cdn.sample.com)
1. 대체 도메인 설정
   - cdn.sample.com
1. Route53 Record 설정
   - A Record cdn.sample.com

### S3 정책 수정

CloudFront에서만의 접근을 허용하도록 정책을 수정한다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::YOUR_ACCOUNT_ID:distribution/YOUR_DISTRIBUTION_ID"
        }
      }
    }
  ]
}
```

### Signed Cookie 생성 (Java 예제 코드)

아래 코드로 인증 만료시간이 10초인 쿠키를 생성할 수 있습니다.

예시에서는 만료시간을 설정하여 테스트 하였으나, 운영환경에서는 만료시간을 설정하지 않습니다. 만료시간을 설정하지 않고 쿠키를 적용시 브라우저가 종료될 때, 쿠키가 사라집니다. 또한 로그인시 쿠키를 제공하기 때문에
만료시간을 설정한다면 만료시간을 확인하고 재발급하는 로직이 추가될 수 있습니다.

```java
public class Main {
    public static void main(String[] args) throws Exception {
        CloudFrontUtilities cloudFrontUtilities = CloudFrontUtilities.create();
        String protocol = "https";
        String resourcePath = "/*";
        String cloudFrontUrl = new URL(protocol, DISTRIBUTION_DOMAIN_NAME, resourcePath).toString();
        Instant expireDate = Instant.now().plus(10, ChronoUnit.SECONDS);
        Path path = Paths.get(PRIVATE_KEY_FILE);

        CustomSignerRequest request = CustomSignerRequest.builder()
                .resourceUrl(cloudFrontUrl)
                .privateKey(path)
                .keyPairId(KEY_PAIR_ID)
                .expirationDate(expireDate)
                .build();

        CookiesForCustomPolicy cookies = cloudFrontUtilities.getCookiesForCustomPolicy(request);

        Map<String, List<String>> headers = cookies.createHttpGetRequest().headers();
        StringBuilder cookieBuilder = new StringBuilder();
        cookieBuilder.append("Cookie: ");
        for (String cookie : headers.get("Cookie")) {
            cookieBuilder.append(cookie).append("; ");
        }

        System.out.println(cookies.resourceUrl());
        System.out.println(cookieBuilder);
    }
}
```

{{% / steps %}}

Intellij의 http 파일로 실행 시켜보겠습니다.

```java
GET https://cdn.sample.com/test.png
Cookie:CloudFront-Policy={Value};CloudFront-Signature={Value};CloudFront-Key-Pair-Id={Value};
```

서명된 URL 로 접근을 해보면 `sample.png` 가 잘 보이는 것을 확인할 수 있습니다.

<image src="images/blog/aws/signed-cookie/sample.png"/>

10초 이후 새로고침 하는 경우 서명된 URL이 만료됨으로 `Access denied` 가 발생합니다.

<image src="images/blog/aws/signed-cookie/access_denied.png"/>

### 서버 적용

Java 예제 코드와 동일하게 쿠키를 발급 하는 코드를 백엔드 서버에 적용합니다. 저는 여기서 로그인시 쿠키를 발급 받도록 설정하였습니다.

이제 적용한 웹페이지에서 잘 나오는지 확인 해 봅니다.

### SSL 문제

CloudFront URL을 잘 제공하였고, 백엔드 서버에서 쿠키를 제공하였으나 리소스에 접근할 수 있는 권한이 없었습니다. 크롬 > 개발자 도구 > 네트워크 탭에서 CloudFront 요청 내역을 살펴보면 요청시
Cookie가 포함되어 있지 않습니다. 이는 SSL 미 적용 문제로 개발서버에 SSL을 적용하여 해결하였습니다.

SSL을 우회하는 설정을 할 수도 있지만 SSL이 적용된 운영환경과 최대한 비슷한 환경에서 테스트하기를 지향하기에 우회 설정은 다루지 않겠습니다.

SSL 적용이후 웹 페이지에서 이미지가 잘 나오는지 확인합니다.

### CloudFront 동작 추가 (Public 용)

모든 S3 URL이 서명될 필요는 없습니다. 예를들어 로그인 하기 전에 필요한 리소스가 있을 수 있습니다.

`/static/*` , `/public/*` 등의 경로에 대한 동작을 추가합니다.

이 동작은 '뷰어 액세스 제한' 을 설정하지 않습니다.

## 운영 적용

운영환경에서는 아래 문제를 함께 고려해야합니다.

- 기존 데이터베이스에 S3 URL이 저장되어있음.
- 새롭게 저장되는 URL.
- 운영환경의 도메인이 변경 됨.

위의 문제로 운영이 중단되지 않고 배포하기 위해 아래 순서를 따라야 합니다.

#### 제한사항

기존 S3는 Public 접근이 허용되어 있는 상태입니다.

{{% steps %}}

### 새로운 도메인으로 CloudFront 설정 추가

- 새로운 도메인으로 대체 도메인 설정
- SSL 설정 (`us-east-1`에서 발급)

### CloudFront URL 에 동작 추가

- `/static/*` 등 제한 없는 동작 추가
- Default 경로에는 '뷰어 액세스 제한' 추가

CloudFront URL에는 이제 Signed Cookie로 접근해야하지만 여전히 S3 URL은 Public 이므로 문제 없음.

### Signed Cookie 발급 백엔드 코드 추가

배포 이후 테스트 계정의 프로필 url을 CloudFront URL 로 변경하여 확인합니다.

### URL 저장시 CloudFront URL로 변경하는 백엔드 코드 추가

### 데이터 베이스 마이그레이션 (S3 URL → CloudFront URL)

### S3 Public 액세스 비활성화

{{% / steps %}}

## 추가) CloudFront 에러 페이지 커스텀

쿠키 없이 URL에 접속시 아래 화면이 발생합니다. 이는 사용자에게 필요한 화면이 아니므로 다른 화면으로 교체해줄 필요가 있습니다.

<image src="images/blog/aws/signed-cookie/missing_key.png"/>

CloudFront는 에러 발생시 특정 객체를 반환하도록 '오류 페이지' 설정을 제공합니다.

{{% steps %}}

### 오류 페이지 만들기

`error.html` 등으로 오류 페이지를 생성합니다.

### CloudFront 에 연결된 S3에 `error.html` 파일 업로드

`/static/error.html` 경로에 파일을 업로드 하였습니다.

### CloudFront 에 동작 추가

`/static/` Path에 접근할 때는 Signed Cookie 가 없더라도 접근 가능하도록 동작을 추가합니다.
이 때 '뷰어 액세스 제한' 을 설정하지 않습니다.

### CloudFront 에 '오류 페이지' 추가

예를 들어 HTTP 오류 코드가 403 인 경우 응답 페이지 `/static/error.html` 을 반환하도록 설정합니다.

{{% /steps %}}

이제 사용자에게 자세한 정보가 표기 되지 않고 커스텀 html 파일이 표기됩니다.

<image src="images/blog/aws/signed-cookie/error.html.png"/>