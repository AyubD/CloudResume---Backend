import boto3

def updateTable(table, partitionKey, column):
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table)
        response = table.update_item(
                Key={
                partitionKey : 'count'
            },
           UpdateExpression='ADD ' + column + ' :value',
            ExpressionAttributeValues={
                ':value':1
            },
            ReturnValues="UPDATED_NEW"
        )

def getCount(table, partitionKey, column):
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table)
        response = table.get_item(
                Key={
                partitionKey : 'count'
            },
        )
        count = response['Item'][column]
        return(count)

def lambda_handler(event, context):
        updateTable('Count', 'id', 'visitor_count')
        getCount('Count', 'id', 'visitor_count')
        
        return {
        'statusCode': 200,
        'headers': { 
                "Access-Control-Allow-Origin": "*" ,
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*",
        },
        'body' : getCount('Count', 'id', 'visitor_count')
        }