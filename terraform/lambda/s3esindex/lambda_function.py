from __future__ import print_function
from pprint import pprint
import boto3
import json
import os
from elasticsearch import Elasticsearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import urllib

import requests

s3 = boto3.client('s3')

region = os.environ['AWS_REGION']
esEndpoint = os.environ['ELASTICSEARCH_ENDPOINT']

service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key,
                   region, service, session_token=credentials.token)

print('Loading function')

indexDoc = {
    "settings": {
        "number_of_shards": 4,
        "number_of_replicas": 1
    }
}


def connectES(esEndPoint):
    print('Connecting to the ES Endpoint {0}'.format(esEndPoint))
    try:
        esClient = Elasticsearch(
            hosts=[{'host': esEndPoint, 'port': 443}],
            http_auth=awsauth,
            use_ssl=True,
            verify_certs=True,
            connection_class=RequestsHttpConnection)
        return esClient
    except Exception as E:
        print("Unable to connect to {0}".format(esEndPoint))
        print(E)
        exit(3)


def createIndex(esClient):
    try:
        res = esClient.indices.exists('metadata-store')
        if res is False:
            esClient.indices.create('metadata-store', body=indexDoc)
            return 1
    except Exception as E:
        print("Unable to Create Index {0}".format("metadata-store"))
        print(E)
        exit(4)


def indexDocElement(esClient, key, response):
    try:
        indexObjectKey = key
        indexcreatedDate = response['LastModified']
        indexcontent_length = response['ContentLength']
        indexcontent_type = response['ContentType']
        indexmetadata = json.dumps(response['Metadata'])
        retval = esClient.index(index='metadata-store', doc_type='images', body={
            'createdDate': indexcreatedDate,
            'objectKey': indexObjectKey,
            'content_type': indexcontent_type,
            'content_length': indexcontent_length,
            'metadata': indexmetadata
        })
    except Exception as E:
        print("Document not indexed")
        print("Error: ", E)
        exit(5)


def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    esClient = connectES(esEndpoint)
    createIndex(esClient)

    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    urllib.parse.unquote_plus
    key = urllib.parse.unquote_plus(
        event['Records'][0]['s3']['object']['key'])
    print('Bucket: {} key: {}'.format(bucket, key))
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        indexDocElement(esClient, key, response)
        return response['ContentType']
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e
