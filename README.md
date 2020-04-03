# Elasticsearch S3 indexer

## Limitations

### Kibana

Kibana performs direct calls to the backend Elasticsearch Client in a number of pages, most notibly the DevTools page as well as the index configuration page. Newer version of kibana (7.6+) have role based access control to restrict these endpoints, but if you want to truely isolate the elasticsearch cluster from users, its best to put a separate API in front of Elasticsearch in order to sanitize and restrict queries to the cluster.

### VPN access

Access to internal resources in this example are exposed via an AWS EC2 Client VPN Endpoint. There are multiple ways to configure this access to this endpoint so for the purposes of this example, access is granted by defining a client root certificate authority which is then imported in to AWS Certificate Manager. Client certificates signed by this CA are accepted by the VPN Endpoint. The resulting OpenVPN configuration can then be used by the client to connect to internal resources in the VPC. An example sanitized configuration is provided in the `extras` directory.