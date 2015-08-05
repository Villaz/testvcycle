__author__ = 'Luis Villazon Esteban'

import json
import time
import sys
import os
import commands
from os import listdir
import xml.etree.ElementTree as ET
import argparse
import ipgetter
import pymongo
from pymongo import MongoClient

import random
import multiprocessing

UNITS = {'HS06': 1., 'SI00': 1. / 344.}

def getCPUNormalization(i, reference='HS06', iterations=1):
    """
    Get Normalized Power of the current CPU in [reference] units
    """
    if reference not in UNITS:
        print('Unknown Normalization unit %s' % str(reference))
    """
        return S_ERROR( 'Unknown Normalization unit %s' % str( reference ) )
    """
    try:
        iter = max(min(int(iterations), 10), 1)
    except (TypeError, ValueError), x:
        print(x)
    """
        return S_ERROR( x )
    """

    # This number of iterations corresponds to 360 HS06 seconds
    n = int(1000 * 1000 * 12.5)
    calib = 360.0 / UNITS[reference]

    m = 0L
    m2 = 0L
    p = 0
    p2 = 0
    # Do one iteration extra to allow CPUs with variable speed
    for i in range(iterations + 1):
        if i == 1:
            start = os.times()
        # Now the iterations
        for j in range(n):
            t = random.normalvariate(10, 1)
            m += t
            m2 += t * t
            p += t
            p2 += t * t

    end = os.times()
    cput = sum( end[:4] ) - sum( start[:4] )
    wall = end[4] - start[4]

    """
    if not cput:
        return S_ERROR( 'Can not get used CPU' )
    """

    return calib * iterations / cput
    """
    print( {'CPU': cput, 'WALL':wall, 'NORM': calib * iterations / cput, 'UNIT': reference } )
    return S_OK( {'CPU': cput, 'WALL':wall, 'NORM': calib * iterations / cput, 'UNIT': reference } )
    """

def extract_values(line):
    """Extract the values from the line and return a dictionary with the value, error, and unit"""

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
    result.update({key: {'entries': int(entries),
                         'cpu': cpu,
                         'real': real,
                         'vmem': vmem
                        }
                   })


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
    result = {'kv': {'start': os.environ['init_kv_test'],
                     'end': os.environ['end_kv_test']}}

    path = "/scratch/KV"
    file_name = None
    for f in listdir(path):
        if f.find("PerfMon_summary_") >= 0:
            file_name = "%s/%s" % (path, f)
            break

    if file_name is None:
        return result

    file = open(file_name, "r")
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
    result = {'phoronix': {'start': os.environ['init_phoronix_test'],
                           'end': os.environ['end_phoronix_test']}}
    for f in listdir(path):
        if f.find('pts-results-viewer') < 0 and f[0] is not '.':
            try:
                tree = ET.parse("%s/%s/%s" % (path, f, "test-1.xml"))
                root = tree.getroot()
                metric = root.find('Result').find('Scale').text
                title = root.find('Result').find('Title').text
                value = float(root.find('Result').find('Data').find('Entry').find('Value').text)
                result['phoronix'].update({title: {'value':float(value), 'unit': metric}})
            except Exception:
                  pass
    return result


def parse_dirac():
    cores = multiprocessing.cpu_count()
    pool = multiprocessing.Pool(processes=cores)
    results = pool.map(getCPUNormalization, range(cores))
    return {'fastBmk': {'value': sum(results), 'unit': 'HS06'}}


def parse_metadata(id, cloud, vo):
    result = {'metadata':{}}
    result.update({'_id': "%s_%s" % (id, str(int(time.time())))})
    result.update({'_timestamp': int(time.time())})
    result['metadata'].update({'ip': ipgetter.myip()})
    result['metadata'].update({'cloud': cloud})
    result['metadata'].update({'UID': id})
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
            if type not in ['evt', 'initialization', 'finalization']: continue;
            if type not in rkv:
                rkv[type] = {}
            entries = 0
            for metric in document['profiles']['kv'][thread][type]:
                if metric == 'entries':
                    entries += document['profiles']['kv'][thread][type]['entries']

                if metric not in ['cpu', 'real']: continue;
                if "%s_values" % metric not in rkv[type]:
                    rkv[type]["%s_values" % metric] = []
                rkv[type]["%s_values" % metric].append(document['profiles']['kv'][thread][type][metric]['value'])
            rkv[type]["entries"] = entries
    return rkv


if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--id", nargs='?', help="VM identifier")
    parser.add_argument("-v", "--vo", nargs='?', help="VO")
    parser.add_argument("-c", "--cloud", nargs='?', help="Cloud")
    args = parser.parse_args()

    result = parse_metadata(args.id, args.cloud, args.vo)
    result.update({'profiles': {}})
    result['profiles'].update(parse_phoronix())
    result['profiles'].update(parse_kv())
    result['profiles'].update({'rkv': generate_rkv(result)})
    result['profiles'].update(parse_dirac())

    file = "/tmp/result_profile.json"
    open(file,'w').write(json.dumps(result))


    mongo_db_url = os.environ['MONGO_DB']
    client = MongoClient(mongo_db_url)
    db = client.infinity
    db.computer_test.find_one_and_update({'hostname': os.environ['HOSTNAME']},{'$set': {'profile': result}})


