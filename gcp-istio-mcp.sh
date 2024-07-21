#!/bin/bash
# 
# Copyright 2019 Shiyghan Navti. Email shiyghan@gmail.com
#
#################################################################################
#### Explore Istio Dual Control Plane Hybrid Cloud Microservice Application #####
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=1 # $(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=1 # $(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Set immutable environment variables
mkdir -p `pwd`/gcp-istio-mcp
export PROJDIR=`pwd`/gcp-istio-mcp
export SCRIPTNAME=gcp-istio-mcp.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT_1=$GCP_PROJECT
export GCP_CLUSTER_1=hipster-dcp-1
export GCP_REGION_1=us-central1
export GCP_ZONE_1=us-central1-a
export GCP_MACHINE_1=e2-standard-2
export GCP_PROJECT_2=$GCP_PROJECT
export GCP_CLUSTER_2=hipster-dcp-2
export GCP_REGION_2=us-central1
export GCP_ZONE_2=us-central1-b
export GCP_MACHINE_2=e2-standard-2
export ISTIO_VERSION=1.22.2
EOF
source $PROJDIR/.env
fi

export APPLICATION_NAME=dual-control-plane
export GCP_SUBNET_1=10.164.0.0/20
export GCP_SUBNET_2=10.128.0.0/20

# Display menu options
while :
do
clear
cat<<EOF
==============================================================
Menu for Dual Control Plane Istio Service Mesh Configuration  
--------------------------------------------------------------
Please enter number to select your choice:
(1) Install tools
(2) Enable APIs
(3) Create network
(4) Create Kubernetes cluster
(5) Install Istio components
(6) Configure application
(Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT_1=$GCP_PROJECT
export GCP_CLUSTER_1=$GCP_CLUSTER_1
export GCP_REGION_1=$GCP_REGION_1
export GCP_ZONE_1=$GCP_ZONE_1
export GCP_MACHINE_1=$GCP_MACHINE_1
export GCP_PROJECT_2=$GCP_PROJECT
export GCP_CLUSTER_2=$GCP_CLUSTER_2
export GCP_REGION_2=$GCP_REGION_2
export GCP_ZONE_2=$GCP_ZONE_2
export GCP_MACHINE_2=$GCP_MACHINE_2
export ISTIO_VERSION=$ISTIO_VERSION
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project 1 is $GCP_PROJECT_1 ***" | pv -qL 100
        echo "*** Google Cloud cluster 1 is $GCP_CLUSTER_1 ***" | pv -qL 100
        echo "*** Google Cloud region 1 is $GCP_REGION_1 ***" | pv -qL 100
        echo "*** Google Cloud zone 1 is $GCP_ZONE_1 ***" | pv -qL 100
        echo "*** Google Cloud machine type 1 is $GCP_MACHINE_1 ***" | pv -qL 100
        echo "*** Google Cloud project 2 is $GCP_PROJECT_2 ***" | pv -qL 100
        echo "*** Google Cloud cluster 2 is $GCP_CLUSTER_2 ***" | pv -qL 100
        echo "*** Google Cloud region 2 is $GCP_REGION_2 ***" | pv -qL 100
        echo "*** Google Cloud zone 2 is $GCP_ZONE_2 ***" | pv -qL 100
        echo "*** Google Cloud machine type 2 is $GCP_MACHINE_2 ***" | pv -qL 100
        echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT_1=$GCP_PROJECT
export GCP_CLUSTER_1=$GCP_CLUSTER_1
export GCP_REGION_1=$GCP_REGION_1
export GCP_ZONE_1=$GCP_ZONE_1
export GCP_MACHINE_1=$GCP_MACHINE_1
export GCP_PROJECT_2=$GCP_PROJECT
export GCP_CLUSTER_2=$GCP_CLUSTER_2
export GCP_REGION_2=$GCP_REGION_2
export GCP_ZONE_2=$GCP_ZONE_2
export GCP_MACHINE_2=$GCP_MACHINE_2
export ISTIO_VERSION=$ISTIO_VERSION
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project 1 is $GCP_PROJECT_1 ***" | pv -qL 100
                echo "*** Google Cloud cluster 1 is $GCP_CLUSTER_1 ***" | pv -qL 100
                echo "*** Google Cloud region 1 is $GCP_REGION_1 ***" | pv -qL 100
                echo "*** Google Cloud zone 1 is $GCP_ZONE_1 ***" | pv -qL 100
                echo "*** Google Cloud machine type 1 is $GCP_MACHINE_1 ***" | pv -qL 100
                echo "*** Google Cloud project 2 is $GCP_PROJECT_2 ***" | pv -qL 100
                echo "*** Google Cloud cluster 2 is $GCP_CLUSTER_2 ***" | pv -qL 100
                echo "*** Google Cloud region 2 is $GCP_REGION_2 ***" | pv -qL 100
                echo "*** Google Cloud zone 2 is $GCP_ZONE_2 ***" | pv -qL 100
                echo "*** Google Cloud machine type 2 is $GCP_MACHINE_2 ***" | pv -qL 100
                echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ curl -L \"https://github.com/istio/istio/releases/download/\${ISTIO_VERSION}/istio-\${ISTIO_VERSION}-linux-amd64.tar.gz\" | tar xz # to download Istio" | pv -qL 100
    echo
    echo "$ pushd certs # to create a directory to hold certificates and keys" | pv -qL 100
    echo
    echo "$ make -f ../tools/certs/Makefile.selfsigned.mk root-ca # to generate the root certificate and key" | pv -qL 100
    echo
    echo "$ make -f ../tools/certs/Makefile.selfsigned.mk \$APPLICATION_NAME-cacerts # to generate an intermediate certificate and key for the Istio CA" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    cd $HOME > /dev/null 2>&1
    echo
    echo "$ curl -L \"https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz\" | tar xz -C $HOME # to download Istio" | pv -qL 100
    curl -L "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz" | tar xz -C $HOME 
    cd istio-${ISTIO_VERSION} > /dev/null 2>&1
    mkdir certs > /dev/null 2>&1
    echo
    echo "$ pushd certs # to create a directory to hold certificates and keys" | pv -qL 100
    pushd certs
    echo
    echo "$ make -f ../tools/certs/Makefile.selfsigned.mk root-ca # to generate the root certificate and key" | pv -qL 100
    make -f ../tools/certs/Makefile.selfsigned.mk root-ca
    echo
    echo "$ make -f ../tools/certs/Makefile.selfsigned.mk $APPLICATION_NAME-cacerts # to generate an intermediate certificate and key for the Istio CA" | pv -qL 100
    make -f ../tools/certs/Makefile.selfsigned.mk $APPLICATION_NAME-cacerts
    export PATH=`pwd`/bin:$PATH > /dev/null 2>&1
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ rm -rf $HOME/istio-${ISTIO_VERSION} # to delete script" | pv -qL 100
    rm -rf $HOME/istio-${ISTIO_VERSION}
else
    export STEP="${STEP},1i"   
    echo
    echo "1. Download Istio" | pv -qL 100
    echo "2. Generate root certificate and key" | pv -qL 100
    echo "3. Generate intermediate certificate and key for Istio CA" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
for i in 1 
do
   if [ $MODE -eq 1 ]; then
        export STEP="${STEP},2i"   
        echo
        echo "$ gcloud --project \$GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},2"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        echo
        echo "$ gcloud --project $PROJECT services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs" | pv -qL 100
        gcloud --project $PROJECT services enable cloudapis.googleapis.com container.googleapis.com
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},2x"   
        echo
        echo "*** Nothing to delete ***" | pv -qL 100
    else
        export STEP="${STEP},2i"
        echo
        echo "1. Enable APIs" | pv -qL 100
    fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},3i(${i})"   
        echo
        echo "$ gcloud --project \$GCP_PROJECT compute networks create \$APPLICATION_NAME-net-${i} --subnet-mode custom # to create custom network" | pv -qL 100
        echo
        echo "$ gcloud --project \$GCP_PROJECT compute networks subnets create \$APPLICATION_NAME-subnet-${i} --network \$APPLICATION_NAME-net-${i} --region \$REGION --range \$SUBNET --enable-flow-logs # to create subnet" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},3(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export GCP_REGION=$(echo GCP_REGION_$(eval "echo $i")) > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export GCP_SUBNET=$(echo GCP_SUBNET_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export REGION=${!GCP_REGION} > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export SUBNET=${!GCP_SUBNET} > /dev/null 2>&1
        echo
        echo "$ gcloud --project $PROJECT compute networks create $APPLICATION_NAME-net-${i} --subnet-mode custom # to create custom network" | pv -qL 100
        gcloud --project $PROJECT compute networks create $APPLICATION_NAME-net-${i} --subnet-mode custom
        echo
        echo "$ gcloud --project $PROJECT compute networks subnets create $APPLICATION_NAME-subnet-${i} --network $APPLICATION_NAME-net-${i} --region $REGION --range $SUBNET --enable-flow-logs # to create  subnet" | pv -qL 100
        gcloud --project $PROJECT compute networks subnets create $APPLICATION_NAME-subnet-${i} --network $APPLICATION_NAME-net-${i} --region $REGION --range $SUBNET --enable-flow-logs
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},3x(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export GCP_REGION=$(echo GCP_REGION_$(eval "echo $i")) > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export GCP_SUBNET=$(echo GCP_SUBNET_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export REGION=${!GCP_REGION} > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export SUBNET=${!GCP_SUBNET} > /dev/null 2>&1
        echo
        echo "$ gcloud --project $PROJECT compute networks subnets delete $APPLICATION_NAME-subnet-${i} --region $REGION --quiet # to delete  subnet" | pv -qL 100
        gcloud --project $PROJECT compute networks subnets delete $APPLICATION_NAME-subnet-${i} --region $REGION --quiet
        echo
        echo "$ gcloud --project $PROJECT compute networks delete $APPLICATION_NAME-net-${i} --quiet # to delete custom network" | pv -qL 100
        gcloud --project $PROJECT compute networks delete $APPLICATION_NAME-net-${i} --quiet
    else
        export STEP="${STEP},3(${i})"   
        echo
        echo "1. Create custom network" | pv -qL 100
        echo "2. Create subnet" | pv -qL 100
    fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},4i(${i})"   
        if [ "$i" -eq 1 ]; then
            echo
            echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$CLUSTER --zone \$ZONE --machine-type e2-standard-2 --num-nodes 2 --network \$APPLICATION_NAME-net-${i} --subnetwork \$APPLICATION_NAME-subnet-${i} --spot # to create container cluster" | pv -qL 100
        else
            echo
            echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$CLUSTER --zone \$ZONE --machine-type e2-standard-2 --num-nodes 2 --network \$APPLICATION_NAME-net-${i} --subnetwork \$APPLICATION_NAME-subnet-${i} --spot # to create container cluster" | pv -qL 100
        fi
        echo
        echo "$ kubectl config use-context \$CTX # to set context" | pv -qL 100
        echo      
        echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\$(gcloud config get-value core/account) # to enable current user to set RBAC rules for Istio" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},4(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export GCP_SUBNET=$(echo GCP_SUBNET_$(eval "echo $i")) > /dev/null 2>&1
        export SUBNET=${!GCP_SUBNET} > /dev/null 2>&1    
        export GCP_MACHINE=$(echo GCP_MACHINE_$(eval "echo $i")) > /dev/null 2>&1
        export MACHINE=${!GCP_MACHINE} > /dev/null 2>&1
        export GCP_NUMNODES=$(echo GCP_NUMNODES_$(eval "echo $i")) > /dev/null 2>&1
        export NUMNODES=${!GCP_NUMNODES} > /dev/null 2>&1
        export GCP_MINNODES=$(echo GCP_MINNODES_$(eval "echo $i")) > /dev/null 2>&1
        export MINNODES=${!GCP_MINNODES} > /dev/null 2>&1
        export GCP_MAXNODES=$(echo GCP_MAXNODES_$(eval "echo $i")) > /dev/null 2>&1
        export MAXNODES=${!GCP_MAXNODES} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        if [ "$i" -eq 1 ]; then
            echo
            echo "$ gcloud --project $PROJECT beta container clusters create $CLUSTER --zone $ZONE --machine-type e2-standard-2 --num-nodes 2 --network $APPLICATION_NAME-net-${i} --subnetwork $APPLICATION_NAME-subnet-${i} --spot # to create container cluster" | pv -qL 100
            gcloud --project $PROJECT beta container clusters create $CLUSTER --zone $ZONE --machine-type e2-standard-2 --num-nodes 2 --network $APPLICATION_NAME-net-${i} --subnetwork $APPLICATION_NAME-subnet-${i} --spot
        else
            echo
            echo "$ gcloud --project $PROJECT beta container clusters create $CLUSTER --zone $ZONE --machine-type e2-standard-2 --num-nodes 2 --network $APPLICATION_NAME-net-${i} --subnetwork $APPLICATION_NAME-subnet-${i} --spot # to create container cluster" | pv -qL 100
            gcloud --project $PROJECT beta container clusters create $CLUSTER --zone $ZONE --machine-type e2-standard-2 --num-nodes 2 --network $APPLICATION_NAME-net-${i} --subnetwork $APPLICATION_NAME-subnet-${i} --spot
        fi
        echo
        echo "$ kubectl config use-context $CTX # to set context" | pv -qL 100
        kubectl config use-context $CTX
        echo      
        gcloud --project $PROJECT container clusters get-credentials $CLUSTER --zone $ZONE > /dev/null 2>&1 # to retrieve the credentials for cluster
        echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\$(gcloud config get-value core/account) # to enable current user to set RBAC rules for Istio" | pv -qL 100
        kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},4x(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export GCP_SUBNET=$(echo GCP_SUBNET_$(eval "echo $i")) > /dev/null 2>&1
        export SUBNET=${!GCP_SUBNET} > /dev/null 2>&1    
        export GCP_MACHINE=$(echo GCP_MACHINE_$(eval "echo $i")) > /dev/null 2>&1
        export MACHINE=${!GCP_MACHINE} > /dev/null 2>&1
        export GCP_NUMNODES=$(echo GCP_NUMNODES_$(eval "echo $i")) > /dev/null 2>&1
        export NUMNODES=${!GCP_NUMNODES} > /dev/null 2>&1
        export GCP_MINNODES=$(echo GCP_MINNODES_$(eval "echo $i")) > /dev/null 2>&1
        export MINNODES=${!GCP_MINNODES} > /dev/null 2>&1
        export GCP_MAXNODES=$(echo GCP_MAXNODES_$(eval "echo $i")) > /dev/null 2>&1
        export MAXNODES=${!GCP_MAXNODES} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        if [ "$i" -eq 1 ]; then
            echo
            echo "$ gcloud --project $PROJECT beta container clusters delete $CLUSTER --zone $ZONE # to delete container cluster" | pv -qL 100
            gcloud --project $PROJECT beta container clusters delete $CLUSTER --zone $ZONE --quiet
        else
            echo
            echo "$ gcloud --project $PROJECT beta container clusters delete $CLUSTER --zone $ZONE # to delete container cluster" | pv -qL 100
            gcloud --project $PROJECT beta container clusters delete $CLUSTER --zone $ZONE --quiet
        fi
    else
        export STEP="${STEP},4(${i})"   
        echo
        echo "1. Create container cluster" | pv -qL 100
        echo "2. Retrieve the credentials for cluster" | pv -qL 100
        echo "3. Enable current user to set RBAC rules" | pv -qL 100
    fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},5i(${i})"   
        echo
        echo "$ kubectl config use-context \$CTX # to set context" | pv -qL 100
        echo      
        echo "$ kubectl create namespace istio-system # to create namespace" | pv -qL 100
        echo
        echo "$ kubectl get namespace istio-system && kubectl label namespace istio-system topology.istio.io/network=\$APPLICATION_NAME-net-${i} # to label namespace" | pv -qL 100
        echo
        echo "$ kubectl create secret generic cacerts -n istio-system --from-file=certs/\$APPLICATION_NAME/ca-cert.pem --from-file=certs/\$APPLICATION_NAME/ca-key.pem --from-file=certs/\$APPLICATION_NAME/root-cert.pem --from-file=certs/\$APPLICATION_NAME/cert-chain.pem # to create secrets" | pv -qL 100
        echo
        echo "$ cat <<EOF> \$PROJDIR/istio-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: \$CLUSTER
      network: \$APPLICATION_NAME-net-${i}
EOF" | pv -qL 100
        echo
        echo "$ \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl install -f \$PROJDIR/istio-cluster.yaml -y # to apply YAML" | pv -qL 100
        echo
        echo "$ \$HOME/istio-\${ISTIO_VERSION}/samples/multicluster/gen-eastwest-gateway.sh --mesh mesh1 --cluster \$CLUSTER --network \$APPLICATION_NAME-net-${i} | \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl --context \$CTX install -y -f - # to install a gateway in cluster1 that is dedicated to east-west traffic" | pv -qL 100
        echo
        echo "$ kubectl apply -n istio-system -f \$HOME/istio-\${ISTIO_VERSION}/samples/multicluster/expose-services.yaml # to expose all services (*.local) on the east-west gateway in both clusters" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},5(${i})"   
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        echo
        echo "$ kubectl config use-context $CTX # to set context" | pv -qL 100
        kubectl config use-context $CTX
        gcloud --project $PROJECT container clusters get-credentials $CLUSTER > /dev/null 2>&1 # to retrieve the credentials for cluster
        cd $HOME/istio-${ISTIO_VERSION} > /dev/null 2>&1 # to change to Istio directory
        echo      
        echo "$ kubectl create namespace istio-system # to create namespace" | pv -qL 100
        kubectl create namespace istio-system
        echo
        echo "$ kubectl get namespace istio-system && kubectl label namespace istio-system topology.istio.io/network=$APPLICATION_NAME-net-${i} # to label namespace" | pv -qL 100
        kubectl get namespace istio-system && kubectl label namespace istio-system topology.istio.io/network=$APPLICATION_NAME-net-${i}
        echo
        kubectl delete secret cacerts -n istio-system > /dev/null 2>&1 
        echo "$ kubectl create secret generic cacerts -n istio-system --from-file=certs/$APPLICATION_NAME/ca-cert.pem --from-file=certs/$APPLICATION_NAME/ca-key.pem --from-file=certs/$APPLICATION_NAME/root-cert.pem --from-file=certs/$APPLICATION_NAME/cert-chain.pem # to create secrets" | pv -qL 100
        kubectl create secret generic cacerts -n istio-system --from-file=certs/$APPLICATION_NAME/ca-cert.pem --from-file=certs/$APPLICATION_NAME/ca-key.pem --from-file=certs/$APPLICATION_NAME/root-cert.pem --from-file=certs/$APPLICATION_NAME/cert-chain.pem
        echo
        echo "$ cat <<EOF> $PROJDIR/istio-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: $CLUSTER
      network: $APPLICATION_NAME-net-${i}
EOF" | pv -qL 100
        cat <<EOF> $PROJDIR/istio-cluster.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: $CLUSTER
      network: $APPLICATION_NAME-net-${i}
EOF
        echo
        echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl install -f $PROJDIR/istio-cluster.yaml -y # to apply YAML" | pv -qL 100
        $HOME/istio-${ISTIO_VERSION}/bin/istioctl install -f $PROJDIR/istio-cluster.yaml -y
        echo && echo
        echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system # to wait for the deployment to finish" | pv -qL 100
        kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system
        echo
        echo "$ $HOME/istio-${ISTIO_VERSION}/samples/multicluster/gen-eastwest-gateway.sh --mesh mesh1 --cluster $CLUSTER --network $APPLICATION_NAME-net-${i} | $HOME/istio-${ISTIO_VERSION}/bin/istioctl --context $CTX install -y -f - # to install a gateway in cluster1 that is dedicated to east-west traffic" | pv -qL 100
        $HOME/istio-${ISTIO_VERSION}/samples/multicluster/gen-eastwest-gateway.sh --mesh mesh1 --cluster $CLUSTER --network $APPLICATION_NAME-net-${i} | $HOME/istio-${ISTIO_VERSION}/bin/istioctl --context $CTX install -y -f -
        echo && echo
        sleep 15
        bash -c 'ISTIOD_ENDPOINT=""; while [ -z $ISTIOD_ENDPOINT ]; do echo "Waiting for end point..."; ISTIOD_ENDPOINT=$(kubectl -n istio-system get svc istio-eastwestgateway  -o jsonpath="{.status.loadBalancer.ingress[0].ip}"); [ -z "$ISTIOD_ENDPOINT" ] && sleep 10; done; echo "End point ready" && echo $ISTIOD_ENDPOINT'
        export ISTIOD_ENDPOINT=$(kubectl -n istio-system get svc istio-eastwestgateway  -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
        echo
        echo "$ kubectl apply -n istio-system -f $HOME/istio-${ISTIO_VERSION}/samples/multicluster/expose-services.yaml # to expose all services (*.local) on the east-west gateway in both clusters" | pv -qL 100
        kubectl apply -n istio-system -f $HOME/istio-${ISTIO_VERSION}/samples/multicluster/expose-services.yaml
        cd $PROJDIR
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},5x(${i})"   
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        echo
        echo "$ kubectl config use-context $CTX # to set context" | pv -qL 100
        kubectl config use-context $CTX
        gcloud --project $PROJECT container clusters get-credentials $CLUSTER > /dev/null 2>&1 # to retrieve the credentials for cluster
        echo
        echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl uninstall --purge # to uninstall istio" | pv -qL 100
        $HOME/istio-${ISTIO_VERSION}/bin/istioctl uninstall --purge 
        echo      
        echo "$ kubectl delete namespace istio-system # to delete namespace" | pv -qL 100
        kubectl delete namespace istio-system
    else
        export STEP="${STEP},5(${i})"   
        echo
        echo "1. Retrieve the credentials for cluster" | pv -qL 100
        echo "2. Create and label namespace" | pv -qL 100
        echo "3. Create cacerts secret" | pv -qL 100
        echo "4. Configure Istio Operator" | pv -qL 100
        echo "5. Configure dedicated east-west gateway" | pv -qL 100
        echo "6. Expose services on east-west gateway" | pv -qL 100
        echo "7. Enable cross-cluster load balancing" | pv -qL 100
        echo "8. Enable cross-cluster load balancing" | pv -qL 100
    fi
done
for ((i=2;i>0;i--)); do 
    if [ $MODE -eq 1 ]; then
        echo
        echo "$ \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl create-remote-secret --name \${HOST_CLUSTER} --context=\${HOST_CTX} | kubectl apply -f - --context=\${REMOTE_CTX} # to enable cross-cluster load balancing" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        export HOST_CLUSTER=${CLUSTER} > /dev/null 2>&1
        export HOST_CTX="${CTX}" > /dev/null 2>&1
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $((3-i))")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $((3-i))")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $((3-i))")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        export REMOTE_CLUSTER=${CLUSTER} > /dev/null 2>&1
        export REMOTE_CTX="${CTX}" > /dev/null 2>&1
        echo
        echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl create-remote-secret --name ${HOST_CLUSTER} --context=${HOST_CTX} | kubectl apply -f - --context=${REMOTE_CTX} # to enable cross-cluster load balancing" | pv -qL 100
        $HOME/istio-${ISTIO_VERSION}/bin/istioctl create-remote-secret --name ${HOST_CLUSTER} --context=${HOST_CTX} | kubectl apply -f - --context=${REMOTE_CTX}
    fi
done 
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
mkdir -p $PROJDIR/cluster1 > /dev/null 2>&1
mkdir -p $PROJDIR/cluster2 > /dev/null 2>&1
cat <<EOF> $PROJDIR/cluster1/deployments.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: emailservice
spec:
  selector:
    matchLabels:
      app: emailservice
  template:
    metadata:
      labels:
        app: emailservice
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/emailservice:v0.3.6
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: DISABLE_PROFILER
          value: "1"
        readinessProbe:
          periodSeconds: 5
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:8080"]
        livenessProbe:
          periodSeconds: 5
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:8080"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkoutservice
spec:
  selector:
    matchLabels:
      app: checkoutservice
  template:
    metadata:
      labels:
        app: checkoutservice
    spec:
      containers:
        - name: server
          image: gcr.io/google-samples/microservices-demo/checkoutservice:v0.3.6
          ports:
          - containerPort: 5050
          readinessProbe:
            exec:
              command: ["/bin/grpc_health_probe", "-addr=:5050"]
          livenessProbe:
            exec:
              command: ["/bin/grpc_health_probe", "-addr=:5050"]
          env:
          - name: PORT
            value: "5050"
          - name: PRODUCT_CATALOG_SERVICE_ADDR
            value: "productcatalogservice:3550"
          - name: SHIPPING_SERVICE_ADDR
            value: "shippingservice:50051"
          - name: PAYMENT_SERVICE_ADDR
            value: "paymentservice:50051"
          - name: EMAIL_SERVICE_ADDR
            value: "emailservice:5000"
          - name: CURRENCY_SERVICE_ADDR
            value: "currencyservice:7000"
          - name: CART_SERVICE_ADDR
            value: "cartservice:7070"
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
      annotations:
        sidecar.istio.io/rewriteAppHTTPProbers: "true"
    spec:
      containers:
        - name: server
          image: gcr.io/google-samples/microservices-demo/frontend:v0.3.6
          ports:
          - containerPort: 8080
          readinessProbe:
            initialDelaySeconds: 10
            httpGet:
              path: "/_healthz"
              port: 8080
              httpHeaders:
              - name: "Cookie"
                value: "shop_session-id=x-readiness-probe"
          livenessProbe:
            initialDelaySeconds: 10
            httpGet:
              path: "/_healthz"
              port: 8080
              httpHeaders:
              - name: "Cookie"
                value: "shop_session-id=x-liveness-probe"
          env:
          - name: PORT
            value: "8080"
          - name: PRODUCT_CATALOG_SERVICE_ADDR
            value: "productcatalogservice:3550"
          - name: CURRENCY_SERVICE_ADDR
            value: "currencyservice:7000"
          - name: CART_SERVICE_ADDR
            value: "cartservice:7070"
          - name: RECOMMENDATION_SERVICE_ADDR
            value: "recommendationservice:8080"
          - name: SHIPPING_SERVICE_ADDR
            value: "shippingservice:50051"
          - name: CHECKOUT_SERVICE_ADDR
            value: "checkoutservice:5050"
          - name: AD_SERVICE_ADDR
            value: "adservice:9555"
          - name: ENV_PLATFORM
            value: "gcp"
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
spec:
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/paymentservice:v0.3.6
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        readinessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:50051"]
        livenessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:50051"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productcatalogservice
spec:
  selector:
    matchLabels:
      app: productcatalogservice
  template:
    metadata:
      labels:
        app: productcatalogservice
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/productcatalogservice:v0.3.6
        ports:
        - containerPort: 3550
        env:
        - name: PORT
          value: "3550"
        readinessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:3550"]
        livenessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:3550"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: currencyservice
spec:
  selector:
    matchLabels:
      app: currencyservice
  template:
    metadata:
      labels:
        app: currencyservice
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/currencyservice:v0.3.6
        ports:
        - name: grpc
          containerPort: 7000
        env:
        - name: PORT
          value: "7000"
        readinessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:7000"]
        livenessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:7000"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shippingservice
spec:
  selector:
    matchLabels:
      app: shippingservice
  template:
    metadata:
      labels:
        app: shippingservice
    spec:
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/shippingservice:v0.3.6
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        readinessProbe:
          periodSeconds: 5
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:50051"]
        livenessProbe:
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:50051"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
EOF
cat <<EOF> $PROJDIR/cluster1/istio-manifests.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: frontend-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-ingress
spec:
  hosts:
  - "*"
  gateways:
  - frontend-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
spec:
  hosts:
  - "frontend.default.svc.cluster.local"
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: whitelist-egress-googleapis
spec:
  hosts:
  - "accounts.google.com" # Used to get token
  - "*.googleapis.com"
  ports:
  - number: 80
    protocol: HTTP
    name: http
  - number: 443
    protocol: HTTPS
    name: https
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: whitelist-egress-google-metadata
spec:
  hosts:
  - metadata.google.internal
  addresses:
  - 169.254.169.254 # GCE metadata server
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
---
EOF
cat <<EOF> $PROJDIR/cluster1/services-all.yaml
apiVersion: v1
kind: Service
metadata:
  name: emailservice
spec:
  type: ClusterIP
  selector:
    app: emailservice
  ports:
  - name: grpc
    port: 5000
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: checkoutservice
spec:
  type: ClusterIP
  selector:
    app: checkoutservice
  ports:
  - name: grpc
    port: 5050
    targetPort: 5050
---
apiVersion: v1
kind: Service
metadata:
  name: recommendationservice
spec:
  type: ClusterIP
  selector:
    app: recommendationservice
  ports:
  - name: grpc
    port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: paymentservice
spec:
  type: ClusterIP
  selector:
    app: paymentservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
apiVersion: v1
kind: Service
metadata:
  name: productcatalogservice
spec:
  type: ClusterIP
  selector:
    app: productcatalogservice
  ports:
  - name: grpc
    port: 3550
    targetPort: 3550
---
apiVersion: v1
kind: Service
metadata:
  name: cartservice
spec:
  type: ClusterIP
  selector:
    app: cartservice
  ports:
  - name: grpc
    port: 7070
    targetPort: 7070
---
apiVersion: v1
kind: Service
metadata:
  name: currencyservice
spec:
  type: ClusterIP
  selector:
    app: currencyservice
  ports:
  - name: grpc
    port: 7000
    targetPort: 7000
---
apiVersion: v1
kind: Service
metadata:
  name: shippingservice
spec:
  type: ClusterIP
  selector:
    app: shippingservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
apiVersion: v1
kind: Service
metadata:
  name: redis-cart
spec:
  type: ClusterIP
  selector:
    app: redis-cart
  ports:
  - name: redis
    port: 6379
    targetPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: adservice
spec:
  type: ClusterIP
  selector:
    app: adservice
  ports:
  - name: grpc
    port: 9555
    targetPort: 9555
---
EOF
cat <<EOF> $PROJDIR/cluster2/deployments.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recommendationservice
spec:
  selector:
    matchLabels:
      app: recommendationservice
  template:
    metadata:
      labels:
        app: recommendationservice
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/recommendationservice:v0.3.6
        ports:
        - containerPort: 8080
        readinessProbe:
          periodSeconds: 5
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:8080"]
        livenessProbe:
          periodSeconds: 5
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:8080"]
        env:
        - name: PORT
          value: "8080"
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        resources:
          requests:
            cpu: 100m
            memory: 220Mi
          limits:
            cpu: 200m
            memory: 450Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cartservice
spec:
  selector:
    matchLabels:
      app: cartservice
  template:
    metadata:
      labels:
        app: cartservice
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: gcr.io/google-samples/microservices-demo/cartservice:v0.3.6
        ports:
        - containerPort: 7070
        env:
        - name: REDIS_ADDR
          value: "redis-cart:6379"
        - name: PORT
          value: "7070"
        - name: LISTEN_ADDR
          value: "0.0.0.0"
        resources:
          requests:
            cpu: 200m
            memory: 64Mi
          limits:
            cpu: 300m
            memory: 128Mi
        readinessProbe:
          initialDelaySeconds: 15
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:7070", "-rpc-timeout=5s"]
        livenessProbe:
          initialDelaySeconds: 15
          periodSeconds: 10
          exec:
            command: ["/bin/grpc_health_probe", "-addr=:7070", "-rpc-timeout=5s"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cart
spec:
  selector:
    matchLabels:
      app: redis-cart
  template:
    metadata:
      labels:
        app: redis-cart
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
        readinessProbe:
          periodSeconds: 5
          tcpSocket:
            port: 6379
        livenessProbe:
          periodSeconds: 5
          tcpSocket:
            port: 6379
        volumeMounts:
        - mountPath: /data
          name: redis-data
        resources:
          limits:
            memory: 256Mi
            cpu: 125m
          requests:
            cpu: 70m
            memory: 200Mi
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loadgenerator
spec:
  selector:
    matchLabels:
      app: loadgenerator
  replicas: 1
  template:
    metadata:
      labels:
        app: loadgenerator
      annotations:
        sidecar.istio.io/rewriteAppHTTPProbers: "true"
    spec:
      terminationGracePeriodSeconds: 5
      restartPolicy: Always
      containers:
      - name: main
        image: gcr.io/google-samples/microservices-demo/loadgenerator:v0.3.6
        env:
        - name: FRONTEND_ADDR
          value: "frontend:80"
        - name: USERS
          value: "10"
        resources:
          requests:
            cpu: 300m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
EOF
cat <<EOF> $PROJDIR/cluster2/services-all.yaml
apiVersion: v1
kind: Service
metadata:
  name: emailservice
spec:
  type: ClusterIP
  selector:
    app: emailservice
  ports:
  - name: grpc
    port: 5000
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: checkoutservice
spec:
  type: ClusterIP
  selector:
    app: checkoutservice
  ports:
  - name: grpc
    port: 5050
    targetPort: 5050
---
apiVersion: v1
kind: Service
metadata:
  name: recommendationservice
spec:
  type: ClusterIP
  selector:
    app: recommendationservice
  ports:
  - name: grpc
    port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: paymentservice
spec:
  type: ClusterIP
  selector:
    app: paymentservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
apiVersion: v1
kind: Service
metadata:
  name: productcatalogservice
spec:
  type: ClusterIP
  selector:
    app: productcatalogservice
  ports:
  - name: grpc
    port: 3550
    targetPort: 3550
---
apiVersion: v1
kind: Service
metadata:
  name: cartservice
spec:
  type: ClusterIP
  selector:
    app: cartservice
  ports:
  - name: grpc
    port: 7070
    targetPort: 7070
---
apiVersion: v1
kind: Service
metadata:
  name: currencyservice
spec:
  type: ClusterIP
  selector:
    app: currencyservice
  ports:
  - name: grpc
    port: 7000
    targetPort: 7000
---
apiVersion: v1
kind: Service
metadata:
  name: shippingservice
spec:
  type: ClusterIP
  selector:
    app: shippingservice
  ports:
  - name: grpc
    port: 50051
    targetPort: 50051
---
apiVersion: v1
kind: Service
metadata:
  name: redis-cart
spec:
  type: ClusterIP
  selector:
    app: redis-cart
  ports:
  - name: redis
    port: 6379
    targetPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: adservice
spec:
  type: ClusterIP
  selector:
    app: adservice
  ports:
  - name: grpc
    port: 9555
    targetPort: 9555
---
EOF
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},6i(${i})"   
        echo
        echo "$ kubectl config use-context \$CTX # to set context" | pv -qL 100
        echo
        echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$CLUSTER # to get cluster credentials" | pv -qL 100
        echo
        echo "$ kubectl label namespace default istio-injection=enabled --overwrite # to label namespace" | pv -qL 100  
        echo
        echo "$ kubectl apply -f \$PROJDIR/cluster${i} # to configure application" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},6(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_REGION=$(echo GCP_REGION_$(eval "echo $i")) > /dev/null 2>&1
        export REGION=${!GCP_REGION} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $GCP_PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        echo
        echo "$ kubectl config use-context $CTX # to set context" | pv -qL 100
        kubectl config use-context $CTX
        echo
        echo "$ gcloud --project $PROJECT container clusters get-credentials $CLUSTER # to get cluster credentials" | pv -qL 100
        gcloud --project $PROJECT container clusters get-credentials $CLUSTER
        echo
        echo "$ kubectl label namespace default istio-injection=enabled --overwrite # to label namespace" | pv -qL 100
        kubectl label namespace default istio-injection=enabled --overwrite
        echo
        echo "$ kubectl apply -f $PROJDIR/cluster${i} # to configure application" | pv -qL 100
        kubectl apply -f $PROJDIR/cluster${i}
    elif [ $MODE -eq 3 ]; then
        export STEP="${STEP},6x(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_REGION=$(echo GCP_REGION_$(eval "echo $i")) > /dev/null 2>&1
        export REGION=${!GCP_REGION} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $GCP_PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        echo
        echo "$ kubectl config use-context $CTX # to set context" | pv -qL 100
        kubectl config use-context $CTX
        echo
        echo "$ gcloud --project $PROJECT container clusters get-credentials $CLUSTER # to get cluster credentials" | pv -qL 100
        gcloud --project $PROJECT container clusters get-credentials $CLUSTER
        echo
        echo "$ kubectl label namespace default istio-injection- # to remove label" | pv -qL 100
        kubectl label namespace default istio-injection-
        echo
        echo "$ kubectl delete -f $PROJDIR/cluster${i} # to configure application" | pv -qL 100
        kubectl delete -f $PROJDIR/cluster${i}
    else
        export STEP="${STEP},6i(${i})"   
        echo
        echo "1. Retrieve credentials for cluster" | pv -qL 100
        echo "2. Create and label namespace" | pv -qL 100
        echo "3. Configure application" | pv -qL 100
    fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-7")
start=`date +%s`
source $PROJDIR/.env
for i in 1 2 
do
    if [ $MODE -eq 1 ]; then
        export STEP="${STEP},7i(${i})"   
        echo
        echo "$ gcloud --project \$GCP_PROJECT beta network-management connectivity-tests create \${APPLICATION_NAME}-connectivity-test-${i} --destination-ip-address=\$FRONTEND_IP --destination-port=80 --destination-project=\$PROJECT --protocol=TCP --source-ip-address=\$CLOUDSHELL_IP --source-project=\$PROJECT --project=\$PROJECT # to configure network test" | pv -qL 100
    elif [ $MODE -eq 2 ]; then
        export STEP="${STEP},7(${i})"   
        export GCP_PROJECT=$(echo GCP_PROJECT_$(eval "echo $i")) > /dev/null 2>&1
        export PROJECT=${!GCP_PROJECT} > /dev/null 2>&1
        export GCP_CLUSTER=$(echo GCP_CLUSTER_$(eval "echo $i")) > /dev/null 2>&1
        export CLUSTER=${!GCP_CLUSTER} > /dev/null 2>&1
        export GCP_REGION=$(echo GCP_REGION_$(eval "echo $i")) > /dev/null 2>&1
        export REGION=${!GCP_REGION} > /dev/null 2>&1
        export GCP_ZONE=$(echo GCP_ZONE_$(eval "echo $i")) > /dev/null 2>&1
        export ZONE=${!GCP_ZONE} > /dev/null 2>&1
        export CTX="gke_${PROJECT}_${ZONE}_${CLUSTER}" > /dev/null 2>&1
        gcloud config set project $GCP_PROJECT > /dev/null 2>&1
        gcloud config set compute/zone $ZONE > /dev/null 2>&1
        echo
        gcloud config set project $PROJECT > /dev/null 2>&1
        kubectl config use-context ${CONFIG_CTX} > /dev/null 2>&1
        gcloud --project $PROJECT container clusters get-credentials ${CONFIG_CLUSTER} --zone ${CONFIG_ZONE} > /dev/null 2>&1
        export CLOUDSHELL_IP=$(dig +short myip.opendns.com @resolver1.opendns.com) # to get cloud shell IP
        export FRONTEND_IP=$(kubectl get svc frontend-external -o jsonpath="{.status.loadBalancer.ingress[0].ip}") # to get frontend external IP for cluster 1
        echo "$ gcloud --project $PROJECT beta network-management connectivity-tests create ${APPLICATION_NAME}-connectivity-test-${i} --destination-ip-address=$FRONTEND_IP --destination-port=80 --destination-project=$PROJECT --protocol=TCP --source-ip-address=$CLOUDSHELL_IP --source-project=$PROJECT --project=$PROJECT # to configure network test" | pv -qL 100
        gcloud --project $PROJECT beta network-management connectivity-tests create ${APPLICATION_NAME}-connectivity-test-${i} --destination-ip-address=$FRONTEND_IP --destination-port=80 --destination-project=$PROJECT --protocol=TCP --source-ip-address=$CLOUDSHELL_IP --source-project=$PROJECT --project=$PROJECT
    else
        export STEP="${STEP},7i(${i})"   
        echo
        echo "1. Configure network test" | pv -qL 100
    fi
done
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
