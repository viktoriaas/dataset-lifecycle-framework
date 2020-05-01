```
$ ./bin/docker-image-tool.sh -r res-drl-hpc-docker-local.artifactory.swg-devops.com/spark-power-k8s -t v2.4.5 -p ./kubernetes/dockerfiles/spark/bindings/python/Dockerfile build
$ ./bin/docker-image-tool.sh -r res-drl-hpc-docker-local.artifactory.swg-devops.com/spark-power-k8s -t v2.4.5 -p ./kubernetes/dockerfiles/spark/bindings/python/Dockerfile push
```
```
$ bin/spark-submit --master k8s://https://hermes004.mul.ie.ibm.com:8443 \
                  --deploy-mode cluster \
                  --name spark-pi \
                  --class org.apache.spark.examples.SparkPi \
                  --conf spark.executor.instances=5 \
                  --conf spark.kubernetes.container.image=res-drl-hpc-docker-local.artifactory.swg-devops.com/spark-power-k8s/spark-py:v2.4.5 \
                  --conf spark.kubernetes.namespace=drlmcdlf 
                  --conf spark.kubernetes.container.image.pullSecrets=art-drl-hpc 
                  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-dlf 
                  local:///opt/spark/examples/src/main/python/pi.py
```
```
bin/spark-submit --master k8s://https://hermes004.mul.ie.ibm.com:8443 --deploy-mode cluster --conf spark.executor.instances=5 --conf spark.kubernetes.container.image=res-drl-hpc-docker-local.artifactory.swg-devops.com/spark-power-k8s/spark-py:v3.0.0-preview --conf spark.kubernetes.namespace=drlmcdlf --conf spark.kubernetes.container.image.pullSecrets=art-drl-hpc --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-dlf --conf spark.kubernetes.container.image.pullPolicy=Always --conf spark.kubernetes.driver.secretKeyRef.AWS_ACCESS_KEY_ID=s3-secret:AWS_ACCESS_KEY_ID --conf spark.kubernetes.driver.secretKeyRef.AWS_SECRET_ACCESS_KEY=s3-secret:AWS_SECRET_ACCESS_KEY --conf spark.kubernetes.executor.secretKeyRef.AWS_ACCESS_KEY_ID=s3-secret:AWS_ACCESS_KEY_ID --conf spark.kubernetes.executor.secretKeyRef.AWS_SECRET_ACCESS_KEY=s3-secret:AWS_SECRET_ACCESS_KEY --conf spark.kubernetes.driver.podTemplateFile=podtemplate.yaml --conf spark.kubernetes.executor.podTemplateFile=podtemplate.yaml local:///opt/spark/examples/example_s3.py
```
```
bin/spark-submit --master k8s://https://hermes004.mul.ie.ibm.com:8443 --deploy-mode cluster --name spark-dlf-s3 --conf spark.executor.instances=5 --conf spark.kubernetes.container.image=res-drl-hpc-docker-local.artifactory.swg-devops.com/spark-power-k8s/spark-py:v3.0.0-rc1 --conf spark.kubernetes.namespace=drlmcdlf --conf spark.kubernetes.container.image.pullSecrets=art-drl-hpc --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-dlf --conf spark.kubernetes.container.image.pullPolicy=Always --conf spark.kubernetes.driver.secretKeyRef.AWS_ACCESS_KEY_ID=s3-secret:AWS_ACCESS_KEY_ID --conf spark.kubernetes.driver.secretKeyRef.AWS_SECRET_ACCESS_KEY=s3-secret:AWS_SECRET_ACCESS_KEY --conf spark.kubernetes.executor.secretKeyRef.AWS_ACCESS_KEY_ID=s3-secret:AWS_ACCESS_KEY_ID --conf spark.kubernetes.executor.secretKeyRef.AWS_SECRET_ACCESS_KEY=s3-secret:AWS_SECRET_ACCESS_KEY local:///opt/spark/examples/example_s3.py
```
