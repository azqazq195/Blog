---
title: Signed Cookie
type: blog
date: 2024-11-02
tags:
  - aws
  - s3
summary: "Learn about secure access methods for content hosted on AWS S3. We compare different security approaches like Pre-signed URLs, Signed URLs, and Signed Cookies, with a focus on using CloudFront Signed Cookies for efficient access control across multiple resources. We'll walk through a practical implementation of Signed Cookies for websites that need to serve multiple secure resources."
---

## The Problem

We had a requirement to hide static S3 URLs while serving content, along with implementing security measures for URL access.

There are three methods for securing S3 URL access:

- Pre-signed URL (S3)
  - Temporary access to a single S3 object
- Signed URL (CloudFront)
  - Access to specific resources through CloudFront
- Signed Cookie (CloudFront)
  - Cookie-based access control for multiple resources through CloudFront

Pre-signed URLs are commonly used when you want clients to upload files directly to S3 without going through your server. The server generates a pre-signed URL for the client, allowing secure file uploads to S3 for a specified duration.

**::We chose Signed Cookies over Signed URLs::** While Signed URLs work well for single object access, they become cumbersome when dealing with multiple resources on a website - you'd need to generate new Signed URLs repeatedly. In contrast, Signed Cookies can grant access to multiple resources with just one cookie setup.

As a side note, Jira uses Blob URLs, which are only valid within the browser session. This approach is suitable for highly confidential projects. We'll cover Blob URL security in a future post.

## Testing

{{% steps %}}

### Generate RSA Keys

Since CloudFront does not generate keys for you, you need to create RSA keys first.

```shell
openssl genrsa -out private_key.pem 2048
openssl rsa -in private_key.pem -pubout -out public_key.pem
```

### Register Public Key

1. CloudFront > Key Management > Public Key

   Register the `public_key.pem` you just created.

1. CloudFront > Key Management > Key Group

   Create a key group with the public key you just registered.

### Create S3 Bucket

Create a test S3 bucket before applying it to the production environment.

- my-test-bucket
- Block all public access
  - Only allow access through CloudFront

### CloudFront Distribution

1. Set up OAC (Allow access only through CloudFront)
2. Viewer access restriction - specify key group

What if you use an alternate domain?

1. Issue and set up SSL for the alternate domain
   - Only certificates issued in ACM us-east-1 can be applied
   - sample.com, \*.sample.com (or cdn.sample.com)
1. Set up the alternate domain
   - cdn.sample.com
1. Set up Route53 Record
   - A Record cdn.sample.com

### Modify S3 Policy

Modify the policy to allow access only through CloudFront.

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

### Generate Signed Cookie (Java Example Code)

The following code generates a cookie with an expiration time of 10 seconds.

In the example, we set an expiration time for testing purposes, but in a production environment, we do not set an expiration time. Without an expiration time, the cookie will disappear when the browser is closed. Additionally, since the cookie is provided upon login, if an expiration time is set, you may need to add logic to check and reissue the cookie.

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

Let's run it using Intellij's http file.

```java
GET https://cdn.sample.com/test.png
Cookie:CloudFront-Policy={Value};CloudFront-Signature={Value};CloudFront-Key-Pair-Id={Value};
```

When you access the signed URL, you can see that `sample.png` is displayed correctly.

![](images/blog/aws/signed-cookie/sample.png)

If you refresh after 10 seconds, the signed URL will expire, resulting in `Access denied`.

![](images/blog/aws/signed-cookie/access_denied.png)

### Server Implementation

Apply the code to issue cookies to the backend server, similar to the Java example code. In this case, I set it to issue cookies upon login.

Now, let's check if the applied webpage displays correctly.

### SSL Issue

Although the CloudFront URL was provided correctly and the backend server issued the cookie, there was no access to the resource. In Chrome > Developer Tools > Network tab, you can see that the CloudFront request does not include the Cookie. This was resolved by applying SSL to the development server.

While you can configure to bypass SSL, we aim to test in an environment as close to the production environment with SSL applied, so we will not cover the bypass configuration.

After applying SSL, check if the image is displayed correctly on the webpage.

### Additional CloudFront Behavior (For Public Use)

Not all S3 URLs need to be signed. For example, there may be resources needed before logging in.

Add behavior for paths like `/static/*`, `/public/*`, etc.

This behavior does not set 'Viewer Access Restriction'.

## Production Deployment

In the production environment, consider the following issues:

- Existing database stores S3 URLs.
- New URLs being saved.
- The domain of the production environment changes.

To deploy without interrupting operations, follow these steps:

#### Constraints

The existing S3 is in a state where public access is allowed.

{{% steps %}}

### Add CloudFront Configuration with New Domain

- Set up an alternate domain with the new domain
- Set up SSL (issued in `us-east-1`)

### Add Behavior to CloudFront URL

- Add unrestricted behavior for paths like `/static/*`
- Add 'Viewer Access Restriction' to the default path

Although the CloudFront URL now requires Signed Cookies, the S3 URL is still public, so there is no issue.

### Add Backend Code to Issue Signed Cookies

After deployment, change the profile URL of a test account to the CloudFront URL and verify.

### Add Backend Code to Save URLs as CloudFront URLs

### Database Migration (S3 URL → CloudFront URL)

### Disable S3 Public Access

{{% / steps %}}

## Additional) Custom CloudFront Error Page

When accessing the URL without a cookie, the following screen appears. This is not a necessary screen for the user, so it needs to be replaced with another screen.

![](images/blog/aws/signed-cookie/missing_key.png)

CloudFront provides an 'Error Pages' setting to return a specific object when an error occurs.

{{% steps %}}

### Create an Error Page

Create an error page like `error.html`.

### Upload `error.html` to the S3 Connected to CloudFront

Upload the file to the `/static/error.html` path.

### Add Behavior to CloudFront

Add behavior to allow access to the `/static/` path even without Signed Cookies.
Do not set 'Viewer Access Restriction' for this behavior.

### Add 'Error Pages' to CloudFront

For example, set it to return the response page `/static/error.html` when the HTTP error code is 403.

{{% /steps %}}

Now, instead of displaying detailed information to the user, the custom HTML file will be displayed.

![](images/blog/aws/signed-cookie/error.html.png)
