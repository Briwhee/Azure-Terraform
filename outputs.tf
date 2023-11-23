output "dsp_network_id" {
  description = "Output of the DSP Network ID to DMZ"
  value       = azurerm_virtual_network.dsp_network.id
}

output "dsp_network_name" {
  description = "Output of the DSP Network Name to DMZ"
  value       = azurerm_virtual_network.dsp_network.name
}

output "dsp_resource_group_name" {
  description = "Output of the DSP Resource Group Name"
  value       = azurerm_resource_group.dsp_resource_group.name
}