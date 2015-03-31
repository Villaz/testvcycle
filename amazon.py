from boto.s3.connection import S3Connection
from boto.exception import S3ResponseError
from boto.s3.key import Key
import os
import sys
from os import listdir
from os.path import isfile, join
import argparse




parser = argparse.ArgumentParser(description='Write the files in S3')
parser.add_argument('host', metavar='host', help='Name of the host, use to create the folder')
parser.add_argument('--AWS_ACCESSKEY', metavar='access', help='amazon S3 access key')
parser.add_argument('--AWS_SECRETKEY', metavar='secret', help='amazon S3 secret key')

args = parser.parse_args()

access_key = os.getenv('AWS_ACCESSKEY', args.AWS_ACCESSKEY)
private_key = os.getenv('AWS_SECRETKEY', args.AWS_SECRETKEY)

if access_key is None or private_key is None:
   print "AWS_ACCESKEY and AWS_SECRETKEY are mandatory"
   sys.exit()

conn = S3Connection(access_key, private_key)
bucket = None
try:
    bucket = conn.get_bucket('vcycle')
except S3ResponseError:
    bucket = conn.create_bucket('vcycle')


files = [ f for f in listdir('/etc/machineoutputs') if isfile(join('/etc/machineoutputs',f)) and '~' not in f ]


for file in files:
    k = Key(bucket)
    k.key = "%s/%s" % (args.host, file)
    k.set_contents_from_filename("/etc/machineoutputs/%s" % file)
