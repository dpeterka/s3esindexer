# Network

## Subnets

The VPC is defined by a /16 network with multiple /24 subnets. These numbers were mostly picked arbitrarally and should be sized to the requirements of the predicted application workloads.

Subnets organized into three separate catagories:
* Public subnets with a route to the internet via an AWS Internet Gateway
* NAT subnets which route all internet traffic through AWS NAT Gateways (NAT gateways exist in the public subnet)
* Private subnets which have no route to the public internet.

Most applications will exist in the NAT subnets. LoadBalancers and other public facing services will exist in public subnets. Databases will exist in the private subnets.