import json
import urllib.parse
import boto3

# print('Loading function')

s3 = boto3.client('s3')
sns = boto3.client('sns')

def lambda_handler(event, context):
    # print("Received event: " + json.dumps(event, indent=2))

    # Get the object, Key and eventName from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
   
    url = "https://%s.s3.amazonaws.com/%s" % (bucket, key)
    # https://test-term-project.s3.amazonaws.com/SHIVAM+MAHAJAN.jpg
   
    # print(url)
    sns_response = sns.publish(
        TargetArn='arn:aws:sns:us-east-1:193337023362:crowd_lambda',
        Message= str(url),
        Subject= "TestSubject"
        )
