
import psutil
import redis
phymem = psutil.phymem_usage()
ram = phymem.total 
r = redis.StrictRedis()
r.set('server_total_memory',ram)



