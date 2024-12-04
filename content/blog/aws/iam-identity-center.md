---
title: IAM Identity Center 설정
type: blog
date: 2024-12-02
tags:
  - aws
summary: ""
weight: 1
---

프로젝트를 시작하게 되면서, 그간 학습했던 AWS 내용을 실제 환경에 적용해보려고 합니다. 이전에는 단순히 Admin 계정을 활용해 빠르게 설계해왔었는데, 보안 문제 발생가능성이 큰 사용 방식이었습니다. 이제 단순 구현에 끝내지 않고 보안 모범 사례를 준수하며, 필요한 서비스에 대해서 충분히 검토하고 설계해 보고자 합니다.

## 보안 모범 사례

루트 계정 모범 사례[^1]에 따르면, 강력한 암호 및 MFA를 활용하여 로그인을 보호하고 사용하지 않는 것을 권장하고 있습니다. IAM의 보안 모범 사례[^2]을 살펴보면, 역시 MFA 활성화를 통한 로그인 보호, 최소 권한을 지키며 임시 보안 인증 사용을 권장합니다. 또한 실제 사람에 할당되는 계정(휴면 유저)에 IAM 유저가 아닌 써보지 않았던 AWS IAM Identity Center[^3]을 권장하기도 합니다. 따라서 이번 프로젝트에서는 루트 계정을 사용하지 않고 IAM Identity Center와 임시 보안 인증을 적극 도입하여 보안을 강화할 예정입니다.

### 장기 자격 증명보다 임시 보안 인증을 권장하는 이유는?

- **보안 강화**: 임시 보안 인증은 일정 시간이 지나면 자동으로 만료됩니다. 따라서 자격 증명이 도난당하거나 유출되더라도 장기적인 피해를 막을 수 있습니다.
- **권한 최소화**: 임시 인증은 특정 작업을 위해 발급되므로 사용자가 접근할 수 있는 범위를 명확히 제한할 수 있습니다.
- **관리 간소화**: 장기 자격 증명은 주기적으로 회전(교체)해야 하지만, 임시 보안 인증은 이를 자동화하여 관리 부담을 줄입니다.

### 휴먼 사용자에게 IAM 대신 IAM Identity Center를 권장하는 이유는?

- **중앙 집중식 관리**: IAM Identity Center를 통해 여러 AWS 계정과 애플리케이션에 대한 액세스를 한곳에서 관리할 수 있습니다. 이는 조직 규모가 커질수록 강력한 관리 도구가 됩니다.
- **보안 강화**: IAM Identity Center는 SSO와 MFA(Multi-Factor Authentication)를 기본적으로 지원하여 IAM 사용자보다 더 강력한 보안 계층을 제공합니다.
- **권한 일관성**: IAM Identity Center는 역할 기반 접근 제어(RBAC)를 통해 각 사용자가 필요로 하는 권한만 부여받도록 보장합니다. 이는 IAM 사용자에서 자주 발생하는 권한 과잉 문제를 해결합니다.
- **간소화된 사용자 경험**: 사용자는 한 번 로그인으로 여러 AWS 계정과 애플리케이션에 쉽게 접근할 수 있어 비즈니스 효율성이 증가합니다.
- **장기 자격 증명의 제거**: IAM Identity Center를 활용하면 장기 자격 증명을 사용할 필요 없이, 세션 기반의 임시 인증으로 보안을 강화할 수 있습니다.

IAM Identity Center를 사전 실습을 통해서 조금 사용해 보았는데, 큰 규모의 조직이 아닌 작은 규모의 조직에서도 충분히 활용 가능해 보였습니다. 관리 비용이 IAM과 비교해 증가할 것 같지 않았고, 확장성은 IAM 보다 뛰어나 보입니다. 인프라 개발자가 한명인 저희 조직에서도 부담 없이 도입할 수 있을 것으로 판단됩니다. 또한, IAM Identity Center는 기본적으로 임시 인증 방식을 사용하기 때문에 장기 자격 증명 관리와 관련된 보안 위험을 줄일 수 있습니다.

- 관리비용이 큰 기술인가? 아니요
- 비용이 발생하는가? 아니요
- 멀리 보았을 때 확장성이 좋은가? 네
- 보안상 이점인가? 네

사용하지 않을 이유가 크게 없어 보입니다..

## 그래서 뭘 해야 하나?

1. 루트 계정에 강력한 암호와 MFA 설정
2. 루트 계정 사용 봉인
3. IAM Identity Center를 사용해 IAM 관리 계정 생성 (1차)
4. IAM 관리 계정으로 IAM Identity Center 관리 (with Terraform)

이번 포스팅에선 `3. IAM Identity Center`로 IAM 관리 계정을 생성해 보겠습니다. 여기서 생성한 IAM 관리 계정으로 다음 포스팅에선 적절한 권한을 갖는 User를 생성해 보겠습니다.

## IAM Identity Center으로 IAM 관리자 계정 만들기

{{% steps %}}

### IAM Identity Center 활성화

먼저 IAM Idnetity Center를 사용하기 위해 사용할 Region에서 활성화를 해줍니다. 이 서비스를 사용하는데 추가적인 비용[^4]은 발생하지 않습니다.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/enable-iam-identity-center-1.png" align="center" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/enable-iam-identity-center-2.png" align="center" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/enable-iam-identity-center-3.png" align="center" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

### IAM Identity Center IAM 관리자 그룹 및 유저 생성

유저는 여러 그룹에 속해있을 수 있습니다. 따라서 권한을 그룹에 매핑하고 필요한 유저에게 그룹을 할당하는 방식으로 관리하려고 합니다. IAM 관리자용 그룹과 유저를 생성해 보겠습니다.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-1.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>4. 그룹에 할당할 사용자를 생성하는 페이지로 이동됩니다.</figcaption>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-2.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-3.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>1. 아직 그룹을 생성하지 않고 사용자 생성 페이지로 넘어왔기 때문에 그룹이 존재하지 않습니다. 그룹을 할당하지 않고 사용자 생성을 완료합니다.</figcaption>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-4.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>1. 방금 생성한 사용자를 할당합니다.</figcaption>
</figure>

### Permission Set 생성

이전 Step 에서 만든 그룹에 실질적으로 권한을 부여해 줍니다. 권한을 부여하기전에 부여할 권한을 먼저 생성합니다.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-permissions-1.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-permissions-2.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-permissions-3.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>IAM Idenetity Center 를 관리하기 위해 세가지 관리형 권한을 추가합니다.</figcaption>
</figure>

### Permission Set 연결

이전 Step 에서 만든 권한 세트를 그룹에 부여합니다.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/attach-permissions-1.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/attach-permissions-2.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>1. 이 그룹을 해당 계정에서 사용</figcaption>
  <figcaption>2. 이 그룹에 해당 권한을 부여함</figcaption>
</figure>

### 생성한 유저의 이메일로 초대 수락

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/invite-user-1.png" align="center"  width="400" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/invite-user-2.png" align="center" width="400" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/invite-user-3.png" align="center" width="400" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/invite-user-4.png" align="center" width="400" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>맥북에서 Passkey를 사용하는 경우 '기본 제공 인증자'로 활용할 수 있습니다. 다른 경우에는 본인의 MFA 디바이스를 등록해주세요.</figcaption>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/invite-user-5.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>로그인이 완료되면 액세스 포털에서 로그인 정보를 확인할 수 있습니다.</figcaption>
  <figcaption>1. 해당 권한을 갖은 채로 AWS Web Console 로 이동합니다.</figcaption>
  <figcaption>2. Session Token이 포함된 액세스 키를 확인할 수 있습니다.</figcaption>
</figure>

{{% / steps %}}

이번 포스팅에서는 IAM Identity Center 활성화와 기본적인 유저 생성방법을 작성해 보았습니다. 다음 포스팅에서는 오늘 작성한 계정을 통해서 Terraform으로 AWS 계정을 관리해 보겠습니다.

<!-- 루트 계정 모범 사례 -->

[^1]: https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/root-user-best-practices.html

<!-- IAM의 보안 모범 사례 -->

[^2]: https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/best-practices.html

<!-- 임시 보안 인증 권장 -->

[^3]: https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/best-practices.html#bp-users-federation-idp

<!-- FAQ IAM Identity Center 요금 -->

[^4]: https://aws.amazon.com/ko/iam/identity-center/faqs/
