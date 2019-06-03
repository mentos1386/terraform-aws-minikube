#####
# Output
#####

output "ssh_user" {
    description = "SSH user to download kubeconfig file"
    value = "ubuntu"
}

output "public_ip" {
    description = "Public IP address"
    value = "${aws_eip.minikube.public_ip}"
}

output "dns" {
    description = "Minikube DNS address"
    value = "${aws_route53_record.minikube.fqdn}"
}

output "kubeconfig" {
    description = "Path to the the kubeconfig file"
    value = "/home/ubuntu/.kube/config"
}

output "docker_certs" {
    description = "Path to the the docker cert files"
    value = "/etc/docker/ssl/*.pem"
}
