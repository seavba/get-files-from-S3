import json
import urllib.parse
import boto3
import os
import random
import string
import shutil

from zipfile import ZipFile

#Starts boto 3 client
s3 = boto3.client('s3')
efs="/mnt/compress"

#function for generating a random string
def get_random_string(length):
    # choose from all lowercase letter
    letters = string.ascii_lowercase
    result_str = ''.join(random.choice(letters) for i in range(length))
    return result_str

temp_dir_name=get_random_string(8)
temp_dir=efs + '/' + temp_dir_name
zip_file=get_random_string(8) + '.zip'
zip_file_name=temp_dir+'/'+zip_file

#Starts Lammda function
def lambda_handler(event, context):
    #Get bucket name and json file updated from the S3 trigger
    bucket = str( event['Records'][0]['s3']['bucket']['name'] )
    key = str( urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8') )

    #Read Json file and get all the image names to be downloaded
    obj = s3.get_object(Bucket=bucket, Key=key)
    json_content = json.loads(obj['Body'].read().decode('utf-8'))

    #creates temporal directoring for working and creates a ZipFile object
    os.makedirs(temp_dir)
    zipObj = ZipFile(zip_file_name , 'w')

    #Download all the images asked for in the json file
    for image in json_content["user_images"]:
        filename=image['image'].split("/")
        filename=str(filename[1])
        s3.download_file(bucket,str(image['image']),temp_dir + '/' + filename)
        #Add images to the zip file
        zipObj.write(str(temp_dir + '/' + filename))
    # close the Zip File
    zipObj.close()
    #Upload zip file to S3
    s3.upload_file(zip_file_name, bucket, 'zip/' + zip_file )
    #Generate URL
    presigned_image_url = s3.generate_presigned_url('get_object', Params={'Bucket': bucket, 'Key': 'zip/' + zip_file}, ExpiresIn=5)
    #Print URL
    print(presigned_image_url)
    #Remove temp dir used during the lambda execution
    shutil.rmtree(temp_dir)
