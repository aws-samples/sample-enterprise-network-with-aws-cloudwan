# CloudWAN Policy with Service Insertion (NFG-based)
# Based on working policy with EgressInspectionVpcs and InspectionVpcs NFGs

locals {
  core_network_policy = {
    version = "2021.12"

    "core-network-configuration" = {
      "asn-ranges"                         = ["64512-65534"]
      "vpn-ecmp-support"                   = false
      "dns-support"                        = true
      "security-group-referencing-support" = false
      "edge-locations" = [
        { location = "us-east-1" }
      ]
    }

    # Segments
    segments = [
      { name = "ingress", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false },
      { name = "egress", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false },
      { name = "inspection", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false },
      { name = "sharedservices", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false },
      { name = "production", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false },
      { name = "development", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false },
      { name = "staging", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false },
      { name = "sandbox", "edge-locations" = ["us-east-1"], "require-attachment-acceptance" = false }
    ]

    # Network Function Groups for Service Insertion
    "network-function-groups" = [
      { name = "EgressInspectionVpcs", "require-attachment-acceptance" = false },
      { name = "InspectionVpcs", "require-attachment-acceptance" = false }
    ]

    # Segment Actions - Service Insertion with NFGs
    "segment-actions" = [
      # Share SharedServices with all workload segments
      {
        action       = "share"
        mode         = "attachment-route"
        segment      = "sharedservices"
        "share-with" = ["production", "development", "staging", "sandbox"]
      },
      # Share Ingress with all segments
      {
        action       = "share"
        mode         = "attachment-route"
        segment      = "ingress"
        "share-with" = ["production", "development", "staging", "sandbox", "sharedservices"]
      },
      # Send production traffic through EgressInspectionVpcs NFG (Egress VPC with inspection)
      {
        action  = "send-to"
        segment = "production"
        via = {
          "network-function-groups" = ["EgressInspectionVpcs"]
        }
      },
      # Send development traffic through EgressInspectionVpcs NFG
      {
        action  = "send-to"
        segment = "development"
        via = {
          "network-function-groups" = ["EgressInspectionVpcs"]
        }
      },
      # Send staging traffic through EgressInspectionVpcs NFG
      {
        action  = "send-to"
        segment = "staging"
        via = {
          "network-function-groups" = ["EgressInspectionVpcs"]
        }
      },
      # Send sandbox traffic through EgressInspectionVpcs NFG
      {
        action  = "send-to"
        segment = "sandbox"
        via = {
          "network-function-groups" = ["EgressInspectionVpcs"]
        }
      },
      # Send development traffic via InspectionVpcs NFG when going to production (east-west inspection)
      {
        action  = "send-via"
        mode    = "dual-hop"
        segment = "development"
        via = {
          "network-function-groups" = ["InspectionVpcs"]
        }
        "when-sent-to" = {
          segments = ["production"]
        }
      },
      # Send production traffic via InspectionVpcs NFG when going to development/staging/sandbox (east-west inspection - symmetric routing)
      {
        action  = "send-via"
        mode    = "dual-hop"
        segment = "production"
        via = {
          "network-function-groups" = ["InspectionVpcs"]
        }
        "when-sent-to" = {
          segments = ["development", "staging", "sandbox"]
        }
      },
      # Send staging traffic via InspectionVpcs NFG when going to production (east-west inspection)
      {
        action  = "send-via"
        mode    = "dual-hop"
        segment = "staging"
        via = {
          "network-function-groups" = ["InspectionVpcs"]
        }
        "when-sent-to" = {
          segments = ["production"]
        }
      },
      # Send sandbox traffic via InspectionVpcs NFG when going to production (east-west inspection)
      {
        action  = "send-via"
        mode    = "dual-hop"
        segment = "sandbox"
        via = {
          "network-function-groups" = ["InspectionVpcs"]
        }
        "when-sent-to" = {
          segments = ["production"]
        }
      }
    ]

    # Attachment Policies
    "attachment-policies" = [
      # Rule 100: Assign VPCs with nfg=inspection to InspectionVpcs NFG
      {
        "rule-number"     = 100
        "condition-logic" = "or"
        conditions = [{
          type     = "tag-value"
          operator = "equals"
          key      = "nfg"
          value    = "inspection"
        }]
        action = {
          "add-to-network-function-group" = "InspectionVpcs"
        }
      },
      # Rule 200: Assign VPCs with nfg=egressinspection to EgressInspectionVpcs NFG
      {
        "rule-number"     = 200
        "condition-logic" = "or"
        conditions = [{
          type     = "tag-value"
          operator = "equals"
          key      = "nfg"
          value    = "egressinspection"
        }]
        action = {
          "add-to-network-function-group" = "EgressInspectionVpcs"
        }
      },
      # Rule 300: Assign VPCs to segments based on "segment" tag value
      {
        "rule-number"     = 300
        "condition-logic" = "or"
        conditions = [{
          type = "tag-exists"
          key  = "segment"
        }]
        action = {
          "association-method" = "tag"
          "tag-value-of-key"   = "segment"
        }
      }
    ]
  }
}

# Apply the policy to the Core Network
resource "aws_networkmanager_core_network_policy_attachment" "main" {
  core_network_id = aws_networkmanager_core_network.main.id
  policy_document = jsonencode(local.core_network_policy)
}

# Wait for policy to propagate
resource "time_sleep" "wait_for_policy" {
  depends_on      = [aws_networkmanager_core_network_policy_attachment.main]
  create_duration = "60s"
}
