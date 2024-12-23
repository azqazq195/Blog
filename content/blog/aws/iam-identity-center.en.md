---
title: IAM Identity Center Setup
type: blog
date: 2024-12-02
tags:
  - aws
summary: "Learn how to create an IAM management account following security best practices using AWS IAM Identity Center. We explore the benefits of temporary security credentials and centralized management, with detailed guidance on the implementation steps."
weight: 1
---

As I begin a new project, I want to apply my AWS knowledge to a real environment. Previously, I simply used an Admin account for quick setup, but this approach posed significant security risks. Now, I aim to go beyond basic implementation by following security best practices and thoroughly reviewing and designing the necessary services.

## Security Best Practices

According to root account best practices[^1], it's recommended to protect login with a strong password and MFA, and avoid using the root account. Looking at IAM security best practices[^2], they also recommend protecting logins through MFA activation and using temporary security credentials while maintaining minimal privileges. Additionally, for accounts assigned to actual people (human users), they recommend using AWS IAM Identity Center[^3] instead of IAM users. Therefore, in this project, we plan to enhance security by not using the root account and actively implementing IAM Identity Center with temporary security credentials.

### Why Are Temporary Security Credentials Recommended Over Long-Term Credentials?

- **Enhanced Security**: Temporary security credentials automatically expire after a certain time. Therefore, even if credentials are stolen or leaked, long-term damage can be prevented.
- **Privilege Minimization**: Temporary credentials are issued for specific tasks, clearly limiting the scope of user access.
- **Simplified Management**: While long-term credentials need periodic rotation, temporary security credentials automate this process, reducing management overhead.

### Why Is IAM Identity Center Recommended Over IAM for Human Users?

- **Centralized Management**: IAM Identity Center allows you to manage access to multiple AWS accounts and applications in one place. This becomes a powerful management tool as organizations grow.
- **Enhanced Security**: IAM Identity Center inherently supports SSO and MFA (Multi-Factor Authentication), providing stronger security layers than IAM users.
- **Permission Consistency**: IAM Identity Center ensures users receive only necessary permissions through role-based access control (RBAC). This solves the common problem of excessive permissions with IAM users.
- **Streamlined User Experience**: Users can easily access multiple AWS accounts and applications with a single login, increasing business efficiency.
- **Elimination of Long-Term Credentials**: Using IAM Identity Center strengthens security through session-based temporary authentication, eliminating the need for long-term credentials.

Through preliminary testing, I found that IAM Identity Center is quite usable even for small organizations, not just large ones. The management overhead doesn't seem to increase compared to IAM, and scalability appears superior. I believe our organization, with just one infrastructure developer, can adopt it without burden. Additionally, IAM Identity Center uses temporary authentication by default, reducing security risks related to long-term credential management.

- Is it a high-maintenance technology? No
- Does it incur costs? No
- Is it scalable in the long term? Yes
- Is it a security advantage? Yes

There doesn't seem to be many reasons not to use it..

## So What Should We Do?

1. Set strong password and MFA for root account
2. Seal root account usage
3. Create IAM management account using IAM Identity Center (Phase 1)
4. Manage IAM Identity Center with IAM management account (with Terraform)

In this post, we'll focus on `3. IAM Identity Center` to create an IAM management account. In the next post, we'll create Users with appropriate permissions using this IAM management account.

## Creating IAM Administrator Account with IAM Identity Center

{{% steps %}}

### Enable IAM Identity Center

First, enable IAM Identity Center in the Region where you'll use it. There are no additional costs[^4] for using this service.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/enable-iam-identity-center-1.png" align="center" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/enable-iam-identity-center-2.png" align="center" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/enable-iam-identity-center-3.png" align="center" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

### Create IAM Identity Center IAM Administrator Group and User

Users can belong to multiple groups. Therefore, we plan to manage permissions by mapping them to groups and assigning groups to users as needed. Let's create a group and user for IAM administrators.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-1.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>4. You'll be directed to the page for creating users to assign to the group.</figcaption>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-2.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-3.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>1. Since we haven't created a group yet, no groups exist. Complete user creation without assigning a group.</figcaption>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-group-and-user-4.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>1. Assign the user we just created.</figcaption>
</figure>

### Create Permission Set

Now we'll grant actual permissions to the group created in the previous step. Before granting permissions, we first create the permissions to be granted.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-permissions-1.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-permissions-2.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/create-permissions-3.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>Add three managed permissions to manage IAM Identity Center.</figcaption>
</figure>

### Connect Permission Set

Grant the permission set created in the previous step to the group.

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/attach-permissions-1.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/attach-permissions-2.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>1. Use this group in that account</figcaption>
  <figcaption>2. Grant these permissions to this group</figcaption>
</figure>

### Accept Invitation from Created User's Email

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
  <figcaption>When using Passkey on MacBook, you can use 'Built-in authenticator'. In other cases, please register your MFA device.</figcaption>
</figure>

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/aws/iam-identity-center/invite-user-5.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>Once logged in, you can check login information in the access portal.</figcaption>
  <figcaption>1. Move to AWS Web Console with these permissions.</figcaption>
  <figcaption>2. You can check access keys that include Session Token.</figcaption>
</figure>

{{% / steps %}}

In this post, we covered IAM Identity Center activation and basic user creation methods. In the next post, we'll manage AWS accounts using Terraform through the account we created today.

<!-- Root account best practices -->

[^1]: https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/root-user-best-practices.html

<!-- IAM security best practices -->

[^2]: https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/best-practices.html

<!-- Recommend temporary security credentials -->

[^3]: https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/best-practices.html#bp-users-federation-idp

<!-- FAQ IAM Identity Center pricing -->

[^4]: https://aws.amazon.com/ko/iam/identity-center/faqs/

