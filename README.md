# AWS Minikube Terraform module

AWS Minikube is a single node Kubernetes deployment in AWS. It creates EC2 host and deploys Kubernetes cluster using Minikube.

<!-- TOC depthFrom:2 -->

- [Prerequisites and dependencies](#prerequisites-and-dependencies)
- [Including the module](#including-the-module)
- [Using custom AMI Image](#using-custom-ami-image)
- [Addons](#addons)
- [Tagging](#tagging)

<!-- /TOC -->


## Prerequisites and dependencies

* AWS Minikube deployes into existing VPC / public subnet. If you don't have your VPC / subnet yet, you can use [this](https://github.com/scholzj/aws-vpc) configuration or [this](https://github.com/scholzj/terraform-aws-vpc) module to create one.
  * The VPC / subnet should be properly linked with Internet Gateway (IGW) and should have DNS and DHCP enabled.
  * Hosted DNS zone configured in Route53 (in case the zone is private you have to use IP address to copy `kubeconfig` and access the cluster).
* To deploy AWS Minikube there are no other dependencies apart from [Terraform](https://www.terraform.io). Minikube is used only on the EC2 host and doesn't have to be installed locally.

## Including the module

Although it can be run on its own, the main value is that it can be included into another Terraform configuration.

```hcl
module "minikube" {
  source = "github.com/scholzj/terraform-aws-minikube"

  aws_region    = "eu-central-1"
  cluster_name  = "my-minikube"
  aws_instance_type = "t2.medium"
  ssh_public_key = "~/.ssh/id_rsa.pub"
  aws_subnet_id = "subnet-8a3517f8"
  ami_image_id = "ami-b81dbfc5"
  hosted_zone = "my-domain.com"
  hosted_zone_private = false

  tags = {
    Application = "Minikube"
  }

  addons = [
    "dashboard"
  ]
}
```

An example of how to include this can be found in the [examples](examples/) dir. 

## Using custom AMI Image

AWS Minikube is built and tested on Ubuntu 18.04. But gives you the possibility to use their own AMI images. Your custom AMI image should be based on Debian based distribution and should be similar to Ubuntu 18.04. When `ami_image_id` variable is not specified, the latest available Ubuntu 18.04 image will be used.

## Addons

Available addons are provided by `minikube addons list`.

The addons will be installed automatically based on the Terraform variables. 


## Tagging

If you need to tag resources created by your Kubernetes cluster (EBS volumes, ELB load balancers etc.) check [this AWS Lambda function which can do the tagging](https://github.com/scholzj/aws-kubernetes-tagging-lambda).
