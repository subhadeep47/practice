# Block  resource_type resource_identifier
#       [provider]_resourceType
resource local_file temp_file {
    filename = "temp.txt"
    content = "This is creted using terraform. Update: changed"
}