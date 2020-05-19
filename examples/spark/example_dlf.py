import os
from pyspark import SparkContext
from pyspark.sql import SparkSession
from pyspark import SparkConf

dataset='bookds'
print(os.environ[dataset+'_accessKeyID'])
print(os.environ[dataset+'_secretAccessKey'])
conf = SparkConf()

sc = SparkContext(conf=conf)
hadoopConf = sc._jsc.hadoopConfiguration()
hadoopConf.set("fs.s3a.access.key", os.environ[dataset+'_accessKeyID'])
hadoopConf.set("fs.s3a.secret.key", os.environ[dataset+'_secretAccessKey'])
hadoopConf.set("fs.s3a.endpoint", os.environ[dataset+'_endpoint'])
hadoopConf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

sql = SparkSession(sc)
books = sql.read.load('s3a://'+os.environ[dataset+'_bucket']+'/books.csv', format="csv", header="true")
books.show()


