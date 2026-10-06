subscription_id     = "a17b18e6-85aa-4663-a636-14a10efc96d6"
resource_group_name = "INCA_FICO"
location            = "centralindia"
project             = "inca-sd"

existing_vnet_name           = "LZ-PREMI1208257-VASHIST_CIN_vNet"
existing_vnet_resource_group = "RG_ITAAS"
pe_subnet_name               = "Subnet-1"
aca_subnet_name              = "Subnet-3"
file_dns_zone_resource_group = "rg_itaas"

# After pushing your image to ACR, change these two and run terraform apply again:
# fastapi_image = "<acr-name>.azurecr.io/inca-fastapi:v1"
# fastapi_port  = 8000


# After pushing your image to ACR, change these two and run terraform apply again:
# fastapi_image = "<acr-name>.azurecr.io/inca-fastapi:v1"
# fastapi_port  = 8000
