import os
from pyspark import SparkContext
from pyspark.sql import SparkSession
from pyspark import SparkConf

print(os.environ['AWS_ACCESS_KEY_ID'])
print(os.environ['AWS_SECRET_ACCESS_KEY'])
conf = SparkConf()

sc = SparkContext(conf=conf)
hadoopConf = sc._jsc.hadoopConfiguration()
hadoopConf.set("fs.s3a.endpoint", "http://s3.eu.cloud-object-storage.appdomain.cloud")
hadoopConf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

sql = SparkSession(sc)
books = sql.read.load('s3a://book-test/books.csv', format="csv", header="true")
books.show()

books.filter(books['year'] > 2000)
books.collect()
print(books.count())
