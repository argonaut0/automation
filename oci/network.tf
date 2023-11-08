resource "oci_core_vcn" "vcn_tiny" {
  cidr_blocks     = ["10.1.0.0/16"]
  compartment_id = var.compartment_ocid
  display_name   = "vcn-tiny"
  dns_label      = "tinyvcn"
  is_ipv6enabled = true
  is_oracle_gua_allocation_enabled = true
}

resource "oci_core_subnet" "subnet_cluster" {
  cidr_block = "10.1.20.0/24"
  display_name      = "subnet-cluster"
  dns_label         = "clustersubnet"
  security_list_ids = [oci_core_security_list.cluster_security_list.id]
  # this will break at some point. assuming exactly one ipv6 block is assigned to the vcn.
  ipv6cidr_blocks = [cidrsubnet(oci_core_vcn.vcn_tiny.ipv6cidr_blocks[0], 8, 0)]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vcn_tiny.id
  route_table_id    = oci_core_route_table.vcn_route_table.id
}


resource "oci_core_internet_gateway" "vcn_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "gateway"
  vcn_id         = oci_core_vcn.vcn_tiny.id
}

resource "oci_core_route_table" "vcn_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn_tiny.id
  display_name   = "vcn-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.vcn_gateway.id
  }

  route_rules {
    destination = "::/0"
    destination_type = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.vcn_gateway.id
  }
}

resource "oci_core_security_list" "cluster_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn_tiny.id
  display_name   = "cluster-node-security-list"

  # Allow all TCP egress
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }
  egress_security_rules {
    protocol    = "6"
    destination = "::/0"
  }

  # Allow ssh over TCP ingress
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "::/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  # Allow wireguard over udp https://docs.k3s.io/installation/requirements
  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"

    udp_options {
      max = "51821"
      min = "51820"
    }
  }
  ingress_security_rules {
    protocol = "17"
    source   = "::/0"

    udp_options {
      max = "51821"
      min = "51820"
    }
  }

  # Allow Metrics
  ingress_security_rules {
    protocol = "6"
    source = "0.0.0.0/0"

    tcp_options {
      max = "10250"
      min = "10250"
    }
  }
  ingress_security_rules {
    protocol = "6"
    source = "::/0"

    tcp_options {
      max = "10250"
      min = "10250"
    }
  }

}