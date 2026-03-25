# Auto-accept CloudWAN attachments using Terraform
# This resource will be created in the Network Services Account context

resource "null_resource" "auto_accept_attachments" {
  provisioner "local-exec" {
    command = <<-EOT
      # Accept any pending CloudWAN attachments
      CORE_NETWORK_ID=$(aws networkmanager list-core-networks --query 'CoreNetworks[0].CoreNetworkId' --output text --region ${var.region})
      
      if [ "$CORE_NETWORK_ID" != "None" ] && [ ! -z "$CORE_NETWORK_ID" ]; then
        PENDING_ATTACHMENTS=$(aws networkmanager list-attachments \
          --core-network-id $CORE_NETWORK_ID \
          --query 'Attachments[?State==`PENDING_ATTACHMENT_ACCEPTANCE`].AttachmentId' \
          --output text --region ${var.region})
        
        for attachment_id in $PENDING_ATTACHMENTS; do
          if [ ! -z "$attachment_id" ] && [ "$attachment_id" != "None" ]; then
            echo "Accepting attachment: $attachment_id"
            aws networkmanager accept-attachment --attachment-id $attachment_id --region ${var.region} || true
          fi
        done
      fi
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}