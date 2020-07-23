#!/bin/bash

#Variables section
DATASET_OPERATOR_NAMESPACE="${DATASET_OPERATOR_NAMESPACE:-default}"
DOCKER_REGISTRY_COMPONENTS="${DOCKER_REGISTRY_COMPONENTS:-the_registry_to_use_for_components}"
export DOCKER_REGISTRY_SECRET="art-drl-hpc"
spark_ver="3.0.0-rc2" #only support 3.0.0-rc1 at the moment
is_minikube=false
minikube_profile="spark-k8s"
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

function build_spark_distribution(){
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
}

function build_spark_images(){
    echo "Copying the example script to the distribution"
    cp example_*.py ${SPARK_EXAMPLE_DIR}/dist/examples/
    cp booktemplate.yaml ${SPARK_EXAMPLE_DIR}/dist/examples/
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
    bucket_suffix=$(shuf -n5 /usr/share/dict/words | grep -E '^[a-z]{4,10}$' | head -n1)
    export bucket_name=book-test-${bucket_suffix}
    #export bucket_name=book-test
    echo "Creating bucket ${bucket_name}"
    cd ${SPARK_EXAMPLE_DIR}
    docker run --rm --network host \
           -e AWS_ACCESS_KEY_ID \
           -e AWS_SECRET_ACCESS_KEY \
           awscli-alpine \
           aws --endpoint ${S3_ENDPOINT} \
           s3 mb s3://${bucket_name}

    if [ $? -eq 0 ]
    then
        echo "Bucket book-test successfully created"
    fi

    docker run --rm --network host \
           -e AWS_ACCESS_KEY_ID \
           -e AWS_SECRET_ACCESS_KEY \
           -v  ${PWD}:/data \
           awscli-alpine \
           aws --endpoint ${S3_ENDPOINT} \
           s3 cp /data/books.csv s3://${bucket_name}/

    if [ $? -eq 0 ]
    then
        echo "books.csv successfully uploaded"
    fi
    
    echo "Creating the book dataset with DLF"
    envsubst < bookdataset.yaml | kubectl apply -n ${DATASET_OPERATOR_NAMESPACE} -f - 
    sleep 20

    if [ $? -eq 0 ]
    then
        echo "Book dataset has been created"
    fi
}

function prepare_k8s(){
    echo "Creating service account and rolebindings in Kubernetes"
    kubectl create serviceaccount -n ${DATASET_OPERATOR_NAMESPACE} spark-dlf
    kubectl create rolebinding spark-role --role=edit --serviceaccount=${DATASET_OPERATOR_NAMESPACE}:spark-dlf --namespace=${DATASET_OPERATOR_NAMESPACE}
    kubectl create role spark-modify-pods --verb=get,list,watch,update,delete,create,patch --resource=pods,deployments,secrets,configmaps,services
    kubectl create rolebinding spark-dlf-xtra --role=spark-modify-pods --serviceaccount=${DATASET_OPERATOR_NAMESPACE}:spark-dlf --namespace=${DATASET_OPERATOR_NAMESPACE}
    kubectl patch -n ${DATASET_OPERATOR_NAMESPACE} serviceaccount/spark-dlf -p '{"imagePullSecrets":[{"name": "${DOCKER_REGISTRY_SECRET}"}]}'
}

function run_spark(){
    echo "Running the example in spark"
    cd ${SPARK_EXAMPLE_DIR}
    #export K8SMASTER=$(kubectl cluster-info | grep -Eoi '(http|https)://[^/"]+$')
    export DOCKER_REGISTRY_COMPONENTS DATASET_OPERATOR_NAMESPACE spark_version=${spark_ver}
    envsubst < spark-client-example.yaml | kubectl apply -n ${DATASET_OPERATOR_NAMESPACE} -f -
}

#check_env
#build_spark_distribution
#build_spark_images
prepare_k8s
create_book_dataset
run_spark
