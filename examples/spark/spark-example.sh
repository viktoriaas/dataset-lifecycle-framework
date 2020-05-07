#!/bin/bash

#Variables section
DATASET_OPERATOR_NAMESPACE="${DATASET_OPERATOR_NAMESPACE:-default}"
DOCKER_REGISTRY_COMPONENTS="${DOCKER_REGISTRY_COMPONENTS:-the_registry_to_use_for_components}"
DOCKER_REGISTRY_SECRET="your_secret_here"
spark_ver="3.0.0-rc1" #only support 3.0.0-rc1 at the moment
is_minikube=true
SPARK_EXAMPLE_DIR=`pwd`

function check_env(){
    echo "Checking if S3 connection variables are available"
    if [[ -z "$S3_ENDPOINT" ]]; then
       echo "Using Nooba for connection credentials"
       if [[ -z "$NOOBAA_HOME" ]]; then
          echo "Noobaa install cannot be found"
          exit 1
       fi
       export S3_ENDPOINT=$(minikube service s3 --url | head -n1)
       export AWS_ACCESS_KEY_ID=$(${NOOBAA_HOME}/noobaa status 2>/dev/null | grep AWS_ACCESS_KEY_ID | awk -F ": " '{print $2}')
       export AWS_SECRET_ACCESS_KEY=$(${NOOBAA_HOME}/noobaa status 2>/dev/null | grep AWS_SECRET_ACCESS_KEY | awk -F ": " '{print $2}')
    fi
}

function build_spark_images(){
    echo "Building distribution for Spark v${spark_ver}"
    docker build --build-arg spark_version=v${spark_ver} -f Dockerfile.build -t spark:v${spark_ver} .
    if [ $? -eq 0 ]; then
       echo "Spark distribution successfully built"
    else 
       echo "Spark distributio could not be created. exiting.."
       exit 1
    fi
    echo "Copying out spark distribution"
    spark_cont=$(docker create spark:v${spark_ver})
    docker cp ${spark_cont}:/opt/spark/dist ${SPARK_EXAMPLE_DIR}
    docker rm ${spark_cont}
    
    echo "Copying the example script to the distribution"
    cp example_*.py ${SPARK_EXAMPLE_DIR}/dist/examples/
    echo "Building Docker images for Spark"
    if [ "$is_minikube" = true ]; then 
    	echo "Building image inside minikube docker env"
        cd ${SPARK_EXAMPLE_DIR}/dist/ &&\
    	./bin/docker-image-tool.sh -m -r ${DOCKER_REGISTRY_COMPONENTS} -t v${spark_ver} -p kubernetes/dockerfiles/spark/bindings/python/Dockerfile build
    else
        echo "Building and pushing images to external registry"
        cd ${SPARK_EXAMPLE_DIR}/dist/ &&\
    	./bin/docker-image-tool.sh -r ${DOCKER_REGISTRY_COMPONENTS} -t v${spark_ver} -p kubernetes/dockerfiles/spark/bindings/python/Dockerfile build &&\
    	./bin/docker-image-tool.sh -r ${DOCKER_REGISTRY_COMPONENTS} -t v${spark_ver} -p kubernetes/dockerfiles/spark/bindings/python/Dockerfile push
    fi
}

function create_book_dataset(){
    echo "Creating S3 bucket and uploading data"
    cd ${SPARK_EXAMPLE_DIR}
    docker run --rm --network host \
           -e AWS_ACCESS_KEY_ID \
               -e AWS_SECRET_ACCESS_KEY \
               awscli-alpine \
               aws --endpoint ${S3_ENDPOINT} \
               s3 mb s3://book-test

    if [ $? -eq 0 ]
    then
        echo "Bucket book-test successfully created"
    fi

    docker run --rm --network host \
           -e AWS_ACCESS_KEY_ID \
               -e AWS_SECRET_ACCESS_KEY \
               -v  ${PWD}:/sampleapp \
               awscli-alpine \
               aws --endpoint ${S3_ENDPOINT} \
               s3 cp ./books.csv s3://book-test/

    if [ $? -eq 0 ]
    then
        echo "books.csv successfully uploaded"
    fi
    
    echo "Creating the book dataset with DLF"
    envsubst < bookdataset.yaml | kubectl apply -n ${DATASET_OPERATOR_NAMESPACE} -f - 

    if [ $? -eq 0 ]
    then
        echo "Book dataset has been created"
    fi
}

function prepare_k8s(){
    echo "Creating service account and rolebindings in Kubernetes"
    kubectl create serviceaccount -n ${DATASET_OPERATOR_NAMESPACE} spark-dlf
    kubectl create rolebinding spark-role --=edit --serviceaccount=${DATASET_OPERATOR_NAMESPACE}:spark-dlf --namespace=${DATASET_OPERATOR_NAMESPACE}
    kubectl create role spark-modify-pods --verb=get,list,watch,update,delete,create,patch --resource=pods,deployments,secrets
    kubectl create rolebinding spark-dlf-xtra --clusterrole=spark-modify-pods --serviceaccount=${DATASET_OPERATOR_NAMESPACE}:spark-dlf --namespace=${DATASET_OPERATOR_NAMESPACE}
}

function run_spark(){
    echo "Running the example in spark"
    cd ${SPARK_EXAMPLE_DIR}/dist
    if [ "$is_minikube" = true ]; then
       echo "Running Spark over DLF dataset inside minikube"
       export K8SMASTER=$(minikube ip)
       bin/spark-submit \
       --master k8s://https://${K8SMASTER}:8443 \
       --deploy-mode cluster \
       --name spark-dlf \
       --conf spark.executor.instances=2 \
       --conf spark.kubernetes.container.image=${DOCKER_REGISTRY_COMPONENTS}/spark-py:${spark_ver} \
       --conf spark.kubernetes.namespace=${DATASET_OPERATOR_NAMESPACE} \
       --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-dlf \
       --conf spark.kubernetes.driver.podTemplateFile=${SPARK_EXAMPLE_DIR}/booktemplate.yaml \
       --conf spark.kubernetes.executor.podTemplateFile=${SPARK_EXAMPLE_DIR}/booktemplate.yaml \
       local:///opt/spark/examples/example_dlf.py
    else
       echo "Running Spark over DLF in the Kubernetes cluster"
       bin/spark-submit \
       --master k8s://https://${K8SMASTER}:8443 \
       --deploy-mode cluster \
       --name spark-dlf \
       --conf spark.executor.instances=5 \
       --conf spark.kubernetes.container.image=${DOCKER_REGISTRY_COMPONENTS}/spark-py:${spark_ver} \
       --conf spark.kubernetes.container.image.pullSecrets=${DOCKER_REGISTRY_SECRET} \
       --conf spark.kubernetes.container.image.pullPolicy=Always \
       --conf spark.kubernetes.namespace=${DATASET_OPERATOR_NAMESPACE} \
       --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-dlf \
       --conf spark.kubernetes.driver.podTemplateFile=${SPARK_EXAMPLE_DIR}/booktemplate.yaml \
       --conf spark.kubernetes.executor.podTemplateFile=${SPARK_EXAMPLE_DIR}/booktemplate.yaml \
       local:///opt/spark/examples/example_dlf.py
    fi   
}

check_env
build_spark_images
prepare_k8s
create_book_dataset
run_spark
