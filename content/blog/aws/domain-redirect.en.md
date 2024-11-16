---
title: Domain Redirect
type: blog
date: 2024-11-01
tags:
  - aws
  - ec2
  - alb
summary: "Learn how to safely transition from *.sample.io to *.sample.com domain using redirection. We'll walk through the complete process of setting up domain redirection using AWS Route 53 and Application Load Balancer (ALB), ensuring a seamless migration without impacting user experience. This guide specifically focuses on implementing domain redirection with ALB for services with multiple subdomains, including real-world application examples."
---

## The Challenge

We needed to set up a redirection from `*.sample.io` to `*.sample.com` and eventually remove the `*.sample.io` domain.

[Redirecting a domain to another domain in Route 53](https://repost.aws/knowledge-center/route-53-redirect-to-another-domain)

AWS suggests three approaches:
- Domain redirection using Amazon S3 and CloudFront
- Domain redirection using Application Load Balancer
- Domain redirection using Amazon CloudFront functions

Since our service already uses Application Load Balancer for domain routing, we decided to go with the second option.

The documentation actually recommends this approach:

> **Note:** It's best to configure your domain using Application Load Balancer instead of Amazon Simple Storage Service (S3).

## Implementation Process

EC2 > Load Balancers

In this screen, you can see all your active load balancers. In our case, we're using three ALBs:

- sample-client-admin-alb
- sample-client-alb
- sample-application-alb

These ALBs are configured with A records in Route 53, directing traffic from `*.sample.io`. I'll skip the detailed configuration as it's well documented in the following guide:

[Redirecting one domain to another using Application Load Balancer](https://repost.aws/knowledge-center/elb-redirect-to-another-domain-with-alb)

One important note: the documentation doesn't cover subdomain configuration in detail. In our case, since each subdomain routes to different ALBs, we need to set up redirects for each one separately.

## Testing

While thinking about how to test these changes before production deployment, I realized there wasn't a way to test without some additional setup. So, I decided to create a temporary ALB to test the URL redirection.

#### Testing Steps

1. First, create a target group (redirect-test-tg) for the ALB. Create it with instance targets, but don't assign any instances.
2. Create an ALB (redirect-test-alb) and select the target group we just created.
3. Register the ALB in Route 53 with an A record.
   - For example, if you connect to `test.sample.io`, you'll see a "503 Service Temporarily Unavailable" page. This is expected since there are no instances in the target group.
4. Add a Redirect listener rule to the ALB (redirect-test-alb) as described in the implementation guide.
   - I set up a redirect from `test.sample.io` to `blog.moseoh.com` (my blog) for testing.
5. Finally, verify the redirect works correctly:
   - `test.sample.io` → `blog.moseoh.com`
   - `test.sample.io/docs` → `blog.moseoh.com/docs`
   - Test with command: `curl -Iv http://test.sample.io -L`

#### Cleaning Up Test Resources

1. Route 53 > Hosted zones > sample.io: Delete `test.sample.io`
2. EC2 > Load Balancers: Delete redirect-test-alb
3. EC2 > Target Groups: Delete redirect-test-tg

Once the test is successful, we can apply the same configuration to our production environment!
