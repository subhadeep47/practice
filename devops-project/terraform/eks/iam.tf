# IAM role of the EKS worker nodes. It is created here, not left to the EKS module's default,
# so it is visible in this repository exactly what the nodes may do.
#
# The nodes (EC2 instances) assume this role. The kubelet uses it to:
#   - register the node with the cluster                (AmazonEKSWorkerNodePolicy)
#   - set up pod networking, the VPC CNI plugin         (AmazonEKS_CNI_Policy)
#   - pull container images from ECR                    (AmazonEC2ContainerRegistryReadOnly)
#   - hand pods their own role credentials (Pod Identity agent), see the inline policy below
# Pods are not meant to use this role for their own AWS calls: those go through a role of
# their own, by IRSA (load balancer controller) or EKS Pod Identity (External Secrets). See
# the README, "How pods get AWS permissions".

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_nodes" {
  name               = "${local.cluster_name}-node"
  description        = "Worker nodes of ${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

locals {
  node_policy_arns = {
    worker_node  = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    cni          = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    ecr_readonly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }
}

resource "aws_iam_role_policy_attachment" "eks_nodes" {
  for_each   = local.node_policy_arns
  role       = aws_iam_role.eks_nodes.name
  policy_arn = each.value
}

# The Pod Identity agent on each node asks EKS for the credentials of a pod's role through this
# call. AmazonEKSWorkerNodePolicy should already include it; it is spelled out here so that
# everything the node role can do is visible in this file.
data "aws_iam_policy_document" "pod_identity_agent" {
  statement {
    actions   = ["eks-auth:AssumeRoleForPodIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "pod_identity_agent" {
  name   = "pod-identity-agent"
  role   = aws_iam_role.eks_nodes.id
  policy = data.aws_iam_policy_document.pod_identity_agent.json
}
