import boto3
import os

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    
    try:
        bucket_name = os.environ['S3_BUCKET_NAME']

        if 'queryStringParameters' in event and 'key' in event['queryStringParameters']:
            object_key = event['queryStringParameters']['key']
        else:
            raise ValueError("Missing 'key' parameter in the query string")

        # 署名付き URL を生成
        presigned_url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': object_key},
            ExpiresIn=3600  # 1時間有効
        )

        return {
            'statusCode': 200,
            'body': presigned_url,
            'headers': {
                'Content-Type': 'text/plain'
            }
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e),
            'headers': {
                'Content-Type': 'text/plain',
            },
        }
