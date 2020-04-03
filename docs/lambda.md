# Publishing lambda functions

## Instructions
```bash
cd terraform/lambda
./build.sh
terraform apply
```

## Details
`build.sh` Performs the following:
1. `pip installs` requirements to a local target destination at `<script_name>\package`
2. zips the packaged dependencies and the lambda function
3. moves the archive to the lambda terraform directory

`terraform apply` keeps track of the checksum of the packaged lambda function and publishes it to AWS if it is different to what exists in the remote state.