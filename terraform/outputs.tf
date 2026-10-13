# To see the details about our resources via output, such as public_ip or public_dns of ec2 resource without going to console
# output "ec2_instance_public_ip" {
#   value = aws_instance.my_ec2[*].public_ip # "[*]" to denote we need to print all resource data since we used count.
# }

# output "ec2_instance_public_dns" {
#   value = aws_instance.my_ec2[*].public_dns
# }

# output "ec2_instance_private_ip" {
#   value = aws_instance.my_ec2[*].private_ip
# }

output "ec2_instance_private_ip" {
  value = {
    for key, instance in aws_instance.my_ec2 : key => instance.public_ip
  } # We have to iterate using for when we are creating multiple resources using for_each
}
