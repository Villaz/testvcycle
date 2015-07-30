import json
import pymongo
import time
import socket
import sys
import os
import commands
import ipgetter
from os import listdir
import xml.etree.ElementTree as ET
from pymongo import MongoClient
import requests
import argparse

def extract_values(line):
    values = line[line.find("(")+1:line.find(")")]
    value = values[:values.find("+")].strip()
    deviation = values[values.find("+/-")+3:].strip()
    unit = line[line.find(")")+1:].strip()
    if unit == 'ms':
            value = '%.5f' % (float(value)/1000)
            deviation = '%.5f' % (float(deviation)/1000)
            unit = 's'
    if float(deviation) == 0:
        return {'value': float(value), 'unit':unit}
    else:
        return {'value': float(value), 'error': float(deviation), 'unit':unit}


def fill_results(result, key, lines, i):
    entries = lines[i][lines[i].find("=")+1:lines[i].find(")")].strip()
    cpu = extract_values(lines[i+1])
    real = extract_values(lines[i+2])
    vmem = extract_values(lines[i+3])
    malloc = extract_values(lines[i+4])
    nalloc = extract_values(lines[i+5])
    rt = extract_values(lines[i+6])
    result.update({key: {'entries': entries,
                         'cpu': cpu,
                         'real': real,
                         'vmem': vmem
                        }
                   })
                       #'malloc': malloc,
                       #'nalloc': nalloc,
                       #'rt': rt} })


def fill_memory_results(result, key, lines, i):
    def extract_memory_value(line):
        value = line[line.find("INFO")+len("INFO"):]
        value = value[value.find(":")+2:].strip()
        unit = value[value.find(" ")+1:].strip()
        value = value[:value.find(" ")]
        return {'value': float(value), 'unit':unit}

    result.update({key:{ 'vm_data': extract_memory_value(lines[i+1]),
                    'vm_exe': extract_memory_value(lines[i+2]),
                    'VmHWM': extract_memory_value(lines[i+3]),
                    'VmLck': extract_memory_value(lines[i+4]),
                    'VmLib': extract_memory_value(lines[i+5]),
                    'VmPTE': extract_memory_value(lines[i+6]),
                    'VmPeak': extract_memory_value(lines[i+7]),
                    'VmRSS': extract_memory_value(lines[i+8]),
                    'VmSize': extract_memory_value(lines[i+9]),
                    'VmStk': extract_memory_value(lines[i+10]),
                    'VmSwap': extract_memory_value(lines[i+11])}})


def fill_memory_leak_results(result, key, lines, i):
    def extract_memory_value(line):
        value = line[line.find("INFO")+len("INFO"):]
        value = value[value.find(":")+2:].strip()
        unit = value[value.find(" ")+1:].strip()
        value = value[:value.find(" ")]
        if unit == 'ms':
            value = round(value/1000, 5)
            unit = 's'
        return {'value': float(value), 'unit':unit}
        return float(value)
    result.update({key: {'first-evt': extract_memory_value(lines[i+1]),
                         '10th -evt':extract_memory_value(lines[i+2]),
                         'last -evt':extract_memory_value(lines[i+3]),
                         'evt  2-20':extract_memory_value(lines[i+4]),
                         'evt 21-50':extract_memory_value(lines[i+5]),
                         'evt 51+':extract_memory_value(lines[i+6])} })


def parse_kv():
    result = {'kv': {}}
    path = "/scratch/KV"
    file_name = None
    for f in listdir(path):
        if f.find("PerfMon_summary_") >= 0:
            file_name = "%s/%s" % (path, f)
            break

    if file_name is None:
        return result

    file = open(file_name, "r")
    reading_stats = False

    lines = file.read().split("\n")
    aux_result = None
    for i in range(0, len(lines)):
        line = lines[i]
        if line.find("## PerfMonFlags ##")> 0:
            thread = line[line.find("KV.thr.")+len("KV.thr.")]
            result['kv'].update({"thr_"+thread:{}})
            aux_result = result['kv']['thr_'+thread]
        if line.find("Statistics for 'ini'") > 0:
            fill_results(aux_result, 'initialization', lines, i)
        if line.find("Statistics for 'evt'") > 0:
            fill_results(aux_result, 'evt', lines, i)
        if line.find("Statistics for 'fin'") > 0:
            fill_results(aux_result, 'finalization', lines, i)
        if line.find("memory infos from") > 0:
            fill_memory_results(aux_result, 'memory', lines, i)
        if line.find("vmem-leak estimation") > 0:
            fill_memory_leak_results(aux_result, 'vmem-leak', lines, i)
    return result


def parse_phoronix():
   path = '/home/phoronix/.phoronix-test-suite/test-results'
   result = {'phoronix': {}}
   for f in listdir(path):
      if f.find('pts-results-viewer') < 0 and f[0] is not '.':
         tree = ET.parse("%s/%s/%s" % (path, f, "test-1.xml"))
         root = tree.getroot()
         title = root.find('Result').find('Title').text
         value = float(root.find('Result').find('Data').find('Entry').find('Value').text)
         result['phoronix'].update({title: float(value)})
   return result


def parse_metadata(cloud, vo):
    result = {'metadata':{}}
    result.update({'_timestamp': int(time.time())})
    result['metadata'].update({'ip': ipgetter.myip()})
    result['metadata'].update({'cloud': cloud})
    result['metadata'].update({'UID': generate_id()})
    result['metadata'].update({'VO': vo})
    result['metadata'].update({'osdist':commands.getoutput("lsb_release -d 2>/dev/null").split(":")[1][1:]})
    result['metadata'].update({'pyver': sys.version.split()[0]})
    result['metadata'].update({'cpuname': commands.getoutput("cat /proc/cpuinfo | grep '^model name' | tail -n 1").split(':')[1].lstrip()})
    result['metadata'].update({'cpunum' : int(commands.getoutput("cat /proc/cpuinfo | grep '^processor' |wc -l"))})
    result['metadata'].update({'bogomips': float(commands.getoutput("cat /proc/cpuinfo | grep '^bogomips' | tail -n 1").split(':')[1].lstrip())})
    result['metadata'].update({'meminfo': float(commands.getoutput("cat /proc/meminfo | grep 'MemTotal:'").split()[1])})
    return result


def generate_rkv(document):
    rkv = {}
    for thread in document['profiles']['kv']:
        for type in document['profiles']['kv'][thread]:
            if type not in rkv:
                rkv[type] = {}
            for metric in document['profiles']['kv'][thread][type]:
                if metric == 'entries': continue;
                if "%s_values" % metric not in rkv[type]:
                    rkv[type]["%s_values" % metric] = []
                rkv[type]["%s_values" % metric].append(document['profiles']['kv'][thread][type][metric]['value'])
    return rkv

def send_queue(host, port, username, password, queue, body):
    import stomp
    import time

    conn = stomp.Connection([(host, int(port))])
    conn.start()
    conn.connect(username, password, True)
    conn.send(body=body, destination=queue)

    time.sleep(2)
    conn.disconnect()


def s3(host_id, cloud, bucket, id, key):
    import boto3
    urls = []
    url = "https://s3-us-west-2.amazonaws.com/%s/%s/%s/" % (bucket, cloud, host_id)

    client = boto3.client('s3', aws_access_key_id=id,
                          aws_secret_access_key=key,
                          )
    try:
        client.put_object(ACL='public-read',
                          Body=open('/home/phoronix/phoronix.tar.gz', 'r').read(),
                          Bucket=bucket,
                          Key="%s/%s/%s" % (cloud, host_id ,'phoronix.tar.gz'))

        client.put_object(ACL='public-read',
                          Body=open('/home/phoronix/kv.tar.gz', 'r').read(),
                          Bucket=bucket,
                          Key="%s/%s/%s" % (cloud, host_id ,'kv.tar.gz'))
        urls.append("%s%s" % (url, 'phoronix.tar.gz'))
        urls.append("%s%s" % (url, 'kv.tar.gz'))
    except:
        pass
    return urls

def generate_id():
    r = requests.get('http://cernvm.cern.ch/config').text
    id = r[r.find('CERNVM_UUID=')+len('CERNVM_UUID='):]
    id = id[:id.find("\n")]
    return id


if __name__ == '__main__':

    mongo_db_url = os.environ['MONGO_DB']
    queue_host = os.environ['QUEUE_HOST']
    queue_port = os.environ['QUEUE_PORT']
    queue_username = os.environ['QUEUE_USERNAME']
    queue_password = os.environ['QUEUE_PASSWORD']
    queue_name = os.environ['QUEUE_NAME']

    aws_bucket = os.environ['AWS_BUCKET']
    aws_key_id = os.environ['AWS_KEY_ID']
    aws_private_key = os.environ['AWS_ACCESS_KEY']

    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--id", nargs='?', help="VM identifier")
    parser.add_argument("-v", "--vo", nargs='?', help="VO")
    parser.add_argument("-c", "--cloud", nargs='?', help="Cloud")
    args = parser.parse_args()


    result = parse_metadata(args.cloud, args.vo)
    result.update({'profiles': {}})
    result['profiles'].update(parse_phoronix())
    result['profiles'].update(parse_kv())
    result['profiles'].update({'rkv': generate_rkv(result)})

    import uuid
    open("/tmp/%s_profile" % str(uuid.uuid4()),'w').write(json.dumps(result))

    send_queue(queue_host,
               queue_port,
               queue_username,
               queue_password,
               queue_name,
               json.dumps(result))

    urls = s3(args.id, args.cloud, aws_bucket, aws_key_id, aws_private_key)

    #save results in MongoDB
    client = MongoClient(mongo_db_url)
    db = client.infinity
    db.computer_test.find_one_and_update({'hostname': args.id},{'$set': {'profile': result, 'urls': urls}})


