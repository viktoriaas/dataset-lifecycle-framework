import os
from pyspark import SparkContext
from pyspark.sql import SparkSession
from pyspark import SparkConf

conf = SparkConf()

sc = SparkContext(conf=conf)
hadoopConf = sc._jsc.hadoopConfiguration()

sql = SparkSession(sc)
books = sql.read.load('/mnt/datasets/bookds/books.csv', format="csv", header="true")
books.show()

books2 = books.filter(books['year'] > 2000)
books2.collect()
books2.show()
