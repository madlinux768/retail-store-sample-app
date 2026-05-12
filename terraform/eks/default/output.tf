output "configure_kubectl" {
  description = "Command to update kubeconfig for this cluster"
  value       = module.retail_app_eks.configure_kubectl
}

output "retail_app_url" {
  description = "Internal URL of the retail store application (requires SSM tunnel)"
  value = try(
    "http://${data.kubernetes_service.ui_service.status[0].load_balancer[0].ingress[0].hostname}",
    "LoadBalancer provisioning - run: kubectl get svc -n ui ui"
  )
}

output "ssm_port_forward_command" {
  description = "SSM command to create a tunnel to the internal load balancer"
  value = try(
    "aws ssm start-session --target <INSTANCE_ID> --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"${data.kubernetes_service.ui_service.status[0].load_balancer[0].ingress[0].hostname}\"],\"portNumber\":[\"80\"],\"localPortNumber\":[\"8888\"]}'",
    "Pending - LB not yet provisioned"
  )
}
