import zc.zk
import random
import time
import os
import psutil
from pprint import pprint

SETTINGS_FILE='/etc/ec2/meta_data.yaml'
from yaml import load, dump
from yaml import Loader, Dumper
f = open(SETTINGS_FILE)
meta_parms = load(f, Loader=Loader)
f.close()


running_in_pydev = 'PYDEV_CONSOLE_ENCODING' in os.environ
if running_in_pydev==True:
    ip = '127.0.0.1'
else:
    ip = meta_parms['ipaddress']  

zk = zc.zk.ZooKeeper('1-zk-aws-development-sydney.gen3media.io:2181')


path = '/sentinel/'
service = 'redis-sentinel'

output = [p.name() for p in psutil.get_process_list()]
if service in output: 
    data = ''
    if zk.exists(path)==None:
        zk.create_recursive(path,data,zc.zk.OPEN_ACL_UNSAFE)
    zk.register(path, (ip, 8080))
    #addresses = zk.children(path)
else:
    exit()


while True:
    running=False
    output = [p.name() for p in psutil.get_process_list()]
    if service in output: 
        time.sleep(2)
        print 'running'
    else:
        print 'proccess is not running'
        exit()


    