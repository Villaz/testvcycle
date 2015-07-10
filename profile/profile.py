import json
import pymongo
import os
from os import listdir
import xml.etree.ElementTree as ET
from pymongo import MongoClient
import argparse


mongo_db_url = os.environ['MONGO_DB']

parser = argparse.ArgumentParser()
parser.add_argument("-i", "--id", nargs='?', help="VM identifier")
args = parser.parse_args()

path = '/home/phoronix/.phoronix-test-suite/test-results'
result = {'phoronix': {}}
for f in listdir(path):
 if f.find('pts-results-viewer') < 0 and f[0] is not '.':
    tree = ET.parse("%s/%s/%s" % (path,f,"test-1.xml"))
    root = tree.getroot()
    title = root.find('Result').find('Title').text
    value = root.find('Result').find('Data').find('Entry').find('Value').text
    result['phoronix'].update({title:value})
open('phoronix.json','w').write(json.dumps(result, indent=2))

#save results in MongoDB
client = MongoClient(mongo_db_url)
db = client.infinity
db.computers.find_one_and_update({'hostname':args.id},{'$set':result})
