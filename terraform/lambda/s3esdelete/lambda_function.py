from __future__ import print_function
from pprint import pprint
import boto3
import json
import os
from elasticsearch import Elasticsearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import urllib


print('Loading function')

region = os.environ['AWS_REGION']
esEndpoint = os.environ['ELASTICSEARCH_ENDPOINT']

service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key,
                   region, service, session_token=credentials.token)


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


def clearMetaData(esClient, key):
    try:
        retval = esClient.search(
            index='metadata-store', q='objectKey.keyword:' + key, filter_path=['hits.hits._id', 'hits.total.value'])
        total = retval['hits']['total']['value']
        count = 0
        while (count < total):
            docId = retval['hits']['hits'][count]['_id']
            print("Deleting: " + docId)
            removeDocElement(esClient, docId)
            count = count + 1
        return 1
    except Exception as E:
        print("Removing metadata failed")
        print("Error: ", E)
        exit(5)


def removeDocElement(esClient, docId):
    try:
        retval = esClient.delete(
            index='metadata-store', id=docId)
        print("Deleted: " + docId)
        return 1
    except Exception as E:
        print("DocId delete command failed at ElasticSearch.")
        print("Error: ", E)
        exit(5)


def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))
    esClient = connectES(esEndpoint)

    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(
        event['Records'][0]['s3']['object']['key'])
    try:
        clearMetaData(esClient, key)
        return 'Removed metadata for ' + key
    except Exception as e:
        print(e)
        print('Error removing object metadata from ElasticSearch Domain.')
        raise e
