# IAM role of the EKS worker nodes. It is created here, not left to the EKS module's default,
# so it is visible in this repository exactly what the nodes may do.
#
# The nodes (EC2 instances) assume this role. The kubelet uses it to:
#   - register the node with the cluster                (AmazonEKSWorkerNodePolicy)
#   - set up pod networking, the VPC CNI plugin         (AmazonEKS_CNI_Policy)
#   - pull container images from ECR                    (AmazonEC2ContainerRegistryReadOnly)
# Pods inherit none of this for their own AWS calls: those use IRSA service accounts
# (load balancer controller, External Secrets), see the README.

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
