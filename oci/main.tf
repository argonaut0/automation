// Copyright (c) 2017, 2023, Oracle and/or its affiliates. All rights reserved.
// Licensed under the Mozilla Public License v2.0

provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

variable "instance_shape" {
  default = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" { default = 4 }

variable "instance_shape_config_memory_in_gbs" { default = 24 }

variable "instance_count" { default = 1}

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

resource "oci_core_instance" "k8s-node-free" {
  count = var.instance_count
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "k8s-node-oci-${count.index}"
  shape               = var.instance_shape
  

  shape_config {
    ocpus = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet_cluster.id
    display_name     = "primary-vnic"
    assign_public_ip = true
    hostname_label   = "k8s-node-oci-${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = lookup(data.oci_core_images.node_image.images[0], "id")
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# See https://docs.oracle.com/iaas/images/
data "oci_core_images" "node_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04 Minimal aarch64"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_core_vnic_attachments" "node_vnic_attachments" {
    count = var.instance_count
    compartment_id = var.compartment_ocid
    instance_id = oci_core_instance.k8s-node-free[count.index].id
}

resource "oci_core_ipv6" "node_ipv6" {
    count = var.instance_count
    # First attached vnic of the corresponding instance
    vnic_id = data.oci_core_vnic_attachments.node_vnic_attachments[count.index].vnic_attachments[0].vnic_id
    display_name = "node-${count.index}-ipv6"
}