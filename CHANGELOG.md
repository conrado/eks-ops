# Sat Apr 30 14:39:16 UTC 2022

- fixed destroy command so everything is destroyed in proper order

# Fri Apr 29 13:01:27 UTC 2022

- moved kubernetes app into terraform configuration
- updated documentation

# Thu Apr 28 22:05:44 UTC 2022

added:

- route53 provisitioned hostnames
- acm signed certificate
- ingress setup through terraform
- cloudfront

# Tue Apr 26 21:47:17 UTC 2022

reorganized most of the code structure to add more things from the todo list.

right now we have:

- terraform vpc
- terraform eks
- terraform aws-load-balancer-controller
