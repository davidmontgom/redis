Boot redis cluster from cold start per shard

1) Add redis node
2) Add sentinal server
3) Boot addtional slaves

For AWS no need to add the zookeeper_redis_service
This recipe ensures that all servers inculding sentinal and fully access via ufw