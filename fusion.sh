#!/bin/bash
#### Entitlement key
mkdir fusion
cd fusion
ekey=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJQk0gTWFya2V0cGxhY2UiLCJpYXQiOjE2OTYzNTAzNjQsImp0aSI6IjFmZjcyYmExMzU3NzQzMTFiMGI4YTdjNWU3MDQwYmViIn0.vxK0jmaP7FEv_HeEZ_zLfU0IERFRgnkOWYy9LyMFGwk
entitlementkey=$(echo -n "cp:$ekey" | base64 -w0)
rightekey="$ekey"
rightentitlementkey="$entitlementkey"
echo $rightentitlementkey
typeset -l SO="$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)"

cat << EOF > authority.json
{
  "auth": "$rightentitlementkey",
  "username":"cp",
  "password":"$rightekey"  
}
EOF

oc get secret/pull-secret -n openshift-config -ojson | jq -r '.data[".dockerconfigjson"]' | base64 -d - | jq '.[]."cp.icr.io" += input' - authority.json > temp_config.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=temp_config.json
oc get secret/pull-secret -n openshift-config -ojson | jq -r '.data[".dockerconfigjson"]' | base64 -d -

if [ $SO == "ubuntu" ]; then
  sudo apt install skopeo -y
elif [ $SO == "rhel" ]; then
  sudo dnf -y install skopeo
fi

wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.12/opm-linux-4.12.39.tar.gz
tar -xvf opm-linux-4.12.39.tar.gz

###
cd ..
podman login registry.redhat.io --authfile pull-secret.json
podman login cp.icr.io -u cp -p $ekey

export LOCAL_SECRET_JSON='/home/azureuser/pull-secret.json'
export LOCAL_ISF_REGISTRY="bastion.privateocp.gbm.net:5000"
export LOCAL_ISF_REPOSITORY="fusion-mirror"

IFS='/' read -r NAMESPACE PREFIX <<< "$LOCAL_ISF_REPOSITORY"
if [[ "$PREFIX" != "" ]]; then export TARGET_PATH="$LOCAL_ISF_REGISTRY/$NAMESPACE/$PREFIX";  export REPO_PREFIX=$(echo "$PREFIX"| sed -r 's/\//-/g')-; else export TARGET_PATH="$LOCAL_ISF_REGISTRY/$NAMESPACE"; export REPO_PREFIX=""; fi
#verify both variables set correctly
echo "$TARGET_PATH"
echo "$REPO_PREFIX"

podman login $LOCAL_ISF_REGISTRY -u admin -p passw0rd
## storage fusion
skopeo copy --all docker://cp.icr.io/cp/isf-sds/fusion-ui@sha256:769a525d83b782b7a149a40e2625f2b1ac51f291c3531a09a1e292f3e9dd97f6 docker://$TARGET_PATH/fusion-ui@sha256:769a525d83b782b7a149a40e2625f2b1ac51f291c3531a09a1e292f3e9dd97f6
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-application-operator@sha256:bba8f2756cad3b18f792bee8d51d662c471df1bfb0ec91e32787a05cb362a5c8 docker://$TARGET_PATH/isf-application-operator@sha256:bba8f2756cad3b18f792bee8d51d662c471df1bfb0ec91e32787a05cb362a5c8
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-bkprstr-operator@sha256:7359a17bc71bfd63a774a27186fbf9cff4bc8fc33b784848c6eca7f966fa346f docker://$TARGET_PATH/isf-bkprstr-operator@sha256:7359a17bc71bfd63a774a27186fbf9cff4bc8fc33b784848c6eca7f966fa346f
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-cns-operator@sha256:00497bad94900daa9a7986a897f7c4496ce7491313ba9a05ab7d9adb47fe7b1c docker://$TARGET_PATH/isf-cns-operator@sha256:00497bad94900daa9a7986a897f7c4496ce7491313ba9a05ab7d9adb47fe7b1c
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-data-protection-operator@sha256:19104ea1d62173eeff67c79b66923d041b02ad0bb7650618ed8d7ca655475fcb docker://$TARGET_PATH/isf-data-protection-operator@sha256:19104ea1d62173eeff67c79b66923d041b02ad0bb7650618ed8d7ca655475fcb
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-prereq-operator@sha256:224ea5eadf8e3e4875093d4c43ae9f895999917d6a527ef5c28e370571a53131 docker://$TARGET_PATH/isf-prereq-operator@sha256:224ea5eadf8e3e4875093d4c43ae9f895999917d6a527ef5c28e370571a53131
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-proxy@sha256:f7d33e64e0996a0549f31d5a8353c93a23a08d2726912cf1f13bb75730833d74 docker://$TARGET_PATH/isf-proxy@sha256:f7d33e64e0996a0549f31d5a8353c93a23a08d2726912cf1f13bb75730833d74
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-serviceability-operator@sha256:43c2241507abcc2c2cdfdfa5393a554c98f28782c0676f8344241ee9ed61bb8b docker://$TARGET_PATH/isf-serviceability-operator@sha256:43c2241507abcc2c2cdfdfa5393a554c98f28782c0676f8344241ee9ed61bb8b
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-ui-operator@sha256:7027a8af4650c564110164ba2e726d975a871d23c613abdace5dd6c002451c42 docker://$TARGET_PATH/isf-ui-operator@sha256:7027a8af4650c564110164ba2e726d975a871d23c613abdace5dd6c002451c42
skopeo copy --all docker://cp.icr.io/cp/isf-sds/isf-update-operator@sha256:b4f1c609d0016150b02a83b3e97c471ae5eb7944e02a1fbee38698bc519a6d50 docker://$TARGET_PATH/isf-update-operator@sha256:b4f1c609d0016150b02a83b3e97c471ae5eb7944e02a1fbee38698bc519a6d50
skopeo copy --all docker://cp.icr.io/cp/isf-sds/callhomeclient@sha256:f82752db42e65f562c8537bba2f7f17efde36af4ba1cfeb02813c5a1dd31e5e0 docker://$TARGET_PATH/callhomeclient@sha256:f82752db42e65f562c8537bba2f7f17efde36af4ba1cfeb02813c5a1dd31e5e0
skopeo copy --all docker://cp.icr.io/cp/isf-sds/eventmanager@sha256:f62eb3eeca87965c01045183cd15563aa372f949d5c4f21206df0f0012849d2d docker://$TARGET_PATH/eventmanager@sha256:f62eb3eeca87965c01045183cd15563aa372f949d5c4f21206df0f0012849d2d
skopeo copy --all docker://cp.icr.io/cp/isf-sds/eventmanager-snmp3@sha256:50848c68fdc56d5acbb95ff8d8263710d99062a470076d29691acad913c591ed docker://$TARGET_PATH/eventmanager-snmp3@sha256:50848c68fdc56d5acbb95ff8d8263710d99062a470076d29691acad913c591ed
skopeo copy --all docker://cp.icr.io/cp/isf-sds/logcollector@sha256:2f6647c887264730ef06aee80565acd491c654004912d88cf22290bc7e5c12a9 docker://$TARGET_PATH/logcollector@sha256:2f6647c887264730ef06aee80565acd491c654004912d88cf22290bc7e5c12a9
skopeo copy --all docker://cp.icr.io/cp/isf-sds/spp-dp-operator@sha256:bccd7bc4ab33216b153ca18c2f48d69222ad28e6ff5262161fda3f54ea34f7e7 docker://$TARGET_PATH/spp-dp-operator@sha256:bccd7bc4ab33216b153ca18c2f48d69222ad28e6ff5262161fda3f54ea34f7e7
skopeo copy --all docker://cp.icr.io/cpopen/isf-operator-software-bundle@sha256:cd3ce753b5fd978591b25ba913ba5ad3430a1c304afa3d5116a964fa21ebe27a docker://$TARGET_PATH/isf-operator-software-bundle@sha256:cd3ce753b5fd978591b25ba913ba5ad3430a1c304afa3d5116a964fa21ebe27a
skopeo copy --all docker://registry.redhat.io/openshift4/ose-kube-rbac-proxy@sha256:63482c91717cb5acdf2734bce6ebadd43c6159c6116b6a2a581f4135873ad0dd docker://$TARGET_PATH/openshift4/ose-kube-rbac-proxy@sha256:63482c91717cb5acdf2734bce6ebadd43c6159c6116b6a2a581f4135873ad0dd
skopeo copy --all docker://cp.icr.io/cpopen/isf-operator-software-catalog:2.6.1 docker://$TARGET_PATH/isf-operator-software-catalog:2.6.1

cat << EOF > imagecontentpolicy-fusion.yaml
apiVersion: operator.openshift.io/v1alpha1 
kind: ImageContentSourcePolicy 
metadata: 
  name: isf-fusion-icsp 
spec: 
  repositoryDigestMirrors:  
  - mirrors:
    - $TARGET_PATH 
    source: cp.icr.io/cp/isf-sds 
  - mirrors:
    - $TARGET_PATH 
    source: icr.io/cpopen 
  - mirrors: 
    - $TARGET_PATH/openshift4 
    source: registry.redhat.io/openshift4
EOF

oc apply -f imagecontentpolicy-fusion.yaml

# spectrum scale images
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-core-init@sha256:0d883e9e218d3c5baccbcf525d6a8539803778325fb28553dbf368c5639a97b2 docker://$TARGET_PATH/ibm-spectrum-scale-core-init@sha256:0d883e9e218d3c5baccbcf525d6a8539803778325fb28553dbf368c5639a97b2
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-gui@sha256:b2026fd3f989dca9cbaded2157d0dc14c4d89dc1d1f3db0613c07924eb03e852 docker://$TARGET_PATH/ibm-spectrum-scale-gui@sha256:b2026fd3f989dca9cbaded2157d0dc14c4d89dc1d1f3db0613c07924eb03e852
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/postgres@sha256:c2a30d08a6f9e6c365595fd086c9e0436064c52425f15f72379ecf0807bac518 docker://$TARGET_PATH/postgres@sha256:c2a30d08a6f9e6c365595fd086c9e0436064c52425f15f72379ecf0807bac518
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/ubi-minimal@sha256:65a240ad8bd3f2fff3e18a22ebadc40da0b145616231fc1e16251f3c6dee087a docker://$TARGET_PATH/ubi-minimal@sha256:65a240ad8bd3f2fff3e18a22ebadc40da0b145616231fc1e16251f3c6dee087a
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-pmcollector@sha256:5909d1a1418a5f72f4519c9c4a7608bd08bdcbe23a1d70cbd4c9bf488cf72216 docker://$TARGET_PATH/ibm-spectrum-scale-pmcollector@sha256:5909d1a1418a5f72f4519c9c4a7608bd08bdcbe23a1d70cbd4c9bf488cf72216
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-monitor@sha256:70766c93b2bf352ea42b153913e8eacb156a298e750ddb8d8274d3eecc913c5a docker://$TARGET_PATH/ibm-spectrum-scale-monitor@sha256:70766c93b2bf352ea42b153913e8eacb156a298e750ddb8d8274d3eecc913c5a
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-grafana-bridge@sha256:bc9eb6ac3a92075cb872c45dc5af2c05422868bdb18e2202ccf928d3cc31d889 docker://$TARGET_PATH/ibm-spectrum-scale-grafana-bridge@sha256:bc9eb6ac3a92075cb872c45dc5af2c05422868bdb18e2202ccf928d3cc31d889
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-coredns@sha256:29f943685acbf4c0a111ae70889465130bac94a4d6d5a6bf5efa0f879c2a79b1 docker://$TARGET_PATH/ibm-spectrum-scale-coredns@sha256:29f943685acbf4c0a111ae70889465130bac94a4d6d5a6bf5efa0f879c2a79b1
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/data-management/ibm-spectrum-scale-daemon@sha256:aad29a63c7e6a6ef341babf9896db91a094ba1ecebe0a1112fdf92932bc92fd7 docker://$TARGET_PATH/data-management/ibm-spectrum-scale-daemon@sha256:aad29a63c7e6a6ef341babf9896db91a094ba1ecebe0a1112fdf92932bc92fd7
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/csi/csi-snapshotter@sha256:0d8d81948af4897bd07b86046424f022f79634ee0315e9f1d4cdb5c1c8d51c90 docker://$TARGET_PATH/csi/csi-snapshotter@sha256:0d8d81948af4897bd07b86046424f022f79634ee0315e9f1d4cdb5c1c8d51c90
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/csi/csi-attacher@sha256:08721106b949e4f5c7ba34b059e17300d73c8e9495201954edc90eeb3e6d8461 docker://$TARGET_PATH/csi/csi-attacher@sha256:08721106b949e4f5c7ba34b059e17300d73c8e9495201954edc90eeb3e6d8461
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/csi/csi-provisioner@sha256:e468dddcd275163a042ab297b2d8c2aca50d5e148d2d22f3b6ba119e2f31fa79 docker://$TARGET_PATH/csi/csi-provisioner@sha256:e468dddcd275163a042ab297b2d8c2aca50d5e148d2d22f3b6ba119e2f31fa79
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/csi/livenessprobe@sha256:2b10b24dafdc3ba94a03fc94d9df9941ca9d6a9207b927f5dfd21d59fbe05ba0 docker://$TARGET_PATH/csi/livenessprobe@sha256:2b10b24dafdc3ba94a03fc94d9df9941ca9d6a9207b927f5dfd21d59fbe05ba0
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/csi/csi-node-driver-registrar@sha256:4a4cae5118c4404e35d66059346b7fa0835d7e6319ff45ed73f4bba335cf5183 docker://$TARGET_PATH/csi/csi-node-driver-registrar@sha256:4a4cae5118c4404e35d66059346b7fa0835d7e6319ff45ed73f4bba335cf5183
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/csi/csi-resizer@sha256:3a7bdf5d105783d05d0962fa06ca53032b01694556e633f27366201c2881e01d docker://$TARGET_PATH/csi/csi-resizer@sha256:3a7bdf5d105783d05d0962fa06ca53032b01694556e633f27366201c2881e01d
skopeo copy --all docker://cp.icr.io/cp/spectrum/scale/csi/ibm-spectrum-scale-csi-driver@sha256:573b3b2d349359d7871d53060a0fc7df6e03de2e2900d1be46b4146ab1972fb7 docker://$TARGET_PATH/csi/ibm-spectrum-scale-csi-driver@sha256:573b3b2d349359d7871d53060a0fc7df6e03de2e2900d1be46b4146ab1972fb7
skopeo copy --all docker://icr.io/cpopen/ibm-spectrum-scale-csi-operator@sha256:da7ada19c06b20edc9b3c8067a8380f6879899022dda8a5c1cbed7c15b2a381d docker://$TARGET_PATH/ibm-spectrum-scale-csi-operator@sha256:da7ada19c06b20edc9b3c8067a8380f6879899022dda8a5c1cbed7c15b2a381d
skopeo copy --all docker://icr.io/cpopen/ibm-spectrum-scale-operator@sha256:eb727060999daea0319c3d67ea7eeb1ca24df6984670272f47f8b6774f451a94 docker://$TARGET_PATH/ibm-spectrum-scale-operator@sha256:eb727060999daea0319c3d67ea7eeb1ca24df6984670272f47f8b6774f451a94
skopeo copy --all docker://icr.io/cpopen/ibm-spectrum-scale-must-gather@sha256:f9b4e6570a9ff8194840bbb97cd7f021485dabc806a5115c0e14f06813d580e7 docker://$TARGET_PATH/ibm-spectrum-scale-must-gather@sha256:f9b4e6570a9ff8194840bbb97cd7f021485dabc806a5115c0e14f06813d580e7

cat << EOF > imagecontentpolicy-spectrum.yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: isf-scale-icsp
spec:
  repositoryDigestMirrors: 
  # for scale
  - mirrors:
    - $TARGET_PATH
    source: cp.icr.io/cp/spectrum/scale
  - mirrors:
    - $TARGET_PATH
    source: icr.io/cpopen
EOF

oc apply -f imagecontentpolicy-spectrum.yaml

##ODF 12
cat << EOF > imageset-config-fdf.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
storageConfig:
  registry:
    imageURL: "$TARGET_PATH/isf-df-metadata:latest"
    skipTLS: true
mirror:
  operators:
    - catalog: icr.io/cpopen/isf-data-foundation-catalog:v4.12
      packages:
        - name: "mcg-operator"
        - name: "ocs-operator"
        - name: "odf-csi-addons-operator"
        - name: "odf-multicluster-orchestrator"
        - name: "odf-operator"
        - name: "odr-cluster-operator"
        - name: "odr-hub-operator"
EOF

oc mirror --config imageset-config-fdf.yaml docker://${TARGET_PATH} --dest-skip-tls --ignore-history

cat << EOF > imageset-config-lso.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
storageConfig:
  registry:
    imageURL: "$TARGET_PATH/df/odf-lso-metadata:latest"
    skipTLS: true
mirror:
  operators:
    - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.12
      packages:
        - name: "local-storage-operator"
EOF

oc mirror --config imageset-config-lso.yaml docker://${TARGET_PATH} --dest-skip-tls --ignore-history

cat << EOF > imagecontentsourcepolicy-icsp.yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: isf-fdf-icsp
spec:
  repositoryDigestMirrors:
  - mirrors:
    - $TARGET_PATH/openshift4
    source: registry.redhat.io/openshift4
  - mirrors:
    - $TARGET_PATH/redhat
    source: registry.redhat.io/redhat
  - mirrors:
    - $TARGET_PATH/rhel8
    source: registry.redhat.io/rhel8
  - mirrors:
    - $TARGET_PATH/cp/df
    source: cp.icr.io/cp/df
  - mirrors:
    - $TARGET_PATH/cpopen
    source: cp.icr.io/cpopen
  - mirrors:
    - $TARGET_PATH/cpopen
    source: icr.io/cpopen
  - mirrors:
    - $TARGET_PATH/cp/ibm-ceph
    source: cp.icr.io/cp/ibm-ceph
EOF

oc apply -f imagecontentsourcepolicy-icsp.yaml

cat << EOF > catalogsource-redhat-operators.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
 name: redhat-operators
 namespace: openshift-marketplace
spec:
 displayName: Red Hat Operators
 image: $TARGET_PATH/redhat-operator-index:v4.12
 publisher: Red Hat
 sourceType: grpc
 EOF

 oc apply -f catalogsource-redhat-operators.yaml

#### data cataloging

opm index prune -f registry.redhat.io/redhat/redhat-operator-index:v4.10 -p amq-streams -t "$TARGET_PATH"/data-cataloging-redhat-operator-index:v4.10
podman push "$TARGET_PATH"/data-cataloging-redhat-operator-index:v4.10
nohup oc adm catalog mirror -a "$LOCAL_SECRET_JSON" "$TARGET_PATH"/data-cataloging-redhat-operator-index:v4.10 "$TARGET_PATH" --index-filter-by-os='linux/amd64' &
oc apply -f ImageContentSourcePolicy.yaml

skopeo copy --all docker://icr.io/cpopen/db2u-operator@sha256:b8a70a044e5c0217f43e945231bd5c18b06f35d29e1602083a9a84de175422af docker://$TARGET_PATH/db2u-operator@sha256:b8a70a044e5c0217f43e945231bd5c18b06f35d29e1602083a9a84de175422af
skopeo copy --all docker://icr.io/cpopen/ibm-operator-catalog@sha256:056db327f51ccc094e72f56d24ed0fc0c333369c33e80624f2bdccf7ca813435 docker://$TARGET_PATH/ibm-operator-catalog@sha256:056db327f51ccc094e72f56d24ed0fc0c333369c33e80624f2bdccf7ca813435
skopeo copy --all docker://icr.io/cpopen/ibm-db2uoperator-bundle@sha256:b79ee2e073753a58eaeb1f12794b14afc52c508f6f037407501096cc4a953093 docker://$TARGET_PATH/ibm-db2uoperator-bundle@sha256:b79ee2e073753a58eaeb1f12794b14afc52c508f6f037407501096cc4a953093
skopeo copy --all docker://icr.io/db2u/db2u.graph@sha256:324b61b8ec86750cece9947eb2440a4fcd6c824f48302325fc75bb24d814e642 docker://$TARGET_PATH/db2u/db2u.graph@sha256:324b61b8ec86750cece9947eb2440a4fcd6c824f48302325fc75bb24d814e642
skopeo copy --all docker://icr.io/db2u/db2u.auxiliary.auth@sha256:b7ae8eb8ad8e47010872a395957d76a16eead69adb0c9859dffbb05b4fb8d5d8 docker://$TARGET_PATH/db2u/db2u.auxiliary.auth@sha256:b7ae8eb8ad8e47010872a395957d76a16eead69adb0c9859dffbb05b4fb8d5d8
skopeo copy --all docker://icr.io/db2u/db2u.rest@sha256:62c219aba9cb007455ec970d89ef1a831428fb97435ddd50ff3c0eabd132170a docker://$TARGET_PATH/db2u/db2u.rest@sha256:62c219aba9cb007455ec970d89ef1a831428fb97435ddd50ff3c0eabd132170a
skopeo copy --all docker://icr.io/db2u/db2u.tools@sha256:e9f4457747f6696f1c1004f71cda4f5fbe1e8ebce33c36f93b7cf61009dc5191 docker://$TARGET_PATH/db2u/db2u.tools@sha256:e9f4457747f6696f1c1004f71cda4f5fbe1e8ebce33c36f93b7cf61009dc5191
skopeo copy --all docker://icr.io/db2u/db2u.instdb@sha256:e5c116a3d5790a39704ed879db7570d257ff69167f7b3b0b7a263b3b90b659ec docker://$TARGET_PATH/db2u/db2u.instdb@sha256:e5c116a3d5790a39704ed879db7570d257ff69167f7b3b0b7a263b3b90b659ec
skopeo copy --all docker://icr.io/db2u/db2u@sha256:1eb9acf2c13f331c71fa54d2ed9407672541eed9b099cd64ea6c36d71f4a24da docker://$TARGET_PATH/db2u/db2u@sha256:1eb9acf2c13f331c71fa54d2ed9407672541eed9b099cd64ea6c36d71f4a24da
skopeo copy --all docker://icr.io/db2u/etcd@sha256:341acb4fd18e24221a1a13af87c852c483184616da0742a2a0ad26c8bf180d1e docker://$TARGET_PATH/db2u/etcd@sha256:341acb4fd18e24221a1a13af87c852c483184616da0742a2a0ad26c8bf180d1e
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/mo-ubi-init@sha256:c0e5dcc74add9071e15e3f4e2b6a90a9a2856be5a3c2c45b01356ca854df8ccd docker://$TARGET_PATH/ibm-spectrum-discover/mo-ubi-init@sha256:c0e5dcc74add9071e15e3f4e2b6a90a9a2856be5a3c2c45b01356ca854df8ccd
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/metaocean-api@sha256:f39f93c66ff215e88957fe9facb9bd214a828b453fce7dc05965a2ea7356a4b9 docker://$TARGET_PATH/ibm-spectrum-discover/metaocean-api@sha256:f39f93c66ff215e88957fe9facb9bd214a828b453fce7dc05965a2ea7356a4b9
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/auth@sha256:86b4c9e8cab881ca6d23d391a2413bc203a9045e6023ea735542a13fff87e576 docker://$TARGET_PATH/ibm-spectrum-discover/auth@sha256:86b4c9e8cab881ca6d23d391a2413bc203a9045e6023ea735542a13fff87e576
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/backup-restore@sha256:00b78a0afe874d0f6e5d9d5857445ebcb93e71c77be6fe749835d06b3245a9ed docker://$TARGET_PATH/ibm-spectrum-discover/backup-restore@sha256:00b78a0afe874d0f6e5d9d5857445ebcb93e71c77be6fe749835d06b3245a9ed
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/connmgr@sha256:2a4ea132ab2b91e8d059d862c4a122df4d7f143d3a9b59766bd4cc91dfd934c4 docker://$TARGET_PATH/ibm-spectrum-discover/connmgr@sha256:2a4ea132ab2b91e8d059d862c4a122df4d7f143d3a9b59766bd4cc91dfd934c4
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/connmgr-scheduler@sha256:d786380884eab14767c7d7c4a0e5439d5d345c820bc8133fe1793cb6726a2645 docker://$TARGET_PATH/ibm-spectrum-discover/connmgr-scheduler@sha256:d786380884eab14767c7d7c4a0e5439d5d345c820bc8133fe1793cb6726a2645
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/moconsumer@sha256:c7fe577fb1a6a6cc8a196906580af4c4142db1eb7188c4bb333914a384370447 docker://$TARGET_PATH/ibm-spectrum-discover/moconsumer@sha256:c7fe577fb1a6a6cc8a196906580af4c4142db1eb7188c4bb333914a384370447
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/mo-agent-extract@sha256:ea334594ecc32f98cdc2f970566961e16a3633e6cce03f2acba465a33591fbe3 docker://$TARGET_PATH/ibm-spectrum-discover/mo-agent-extract@sha256:ea334594ecc32f98cdc2f970566961e16a3633e6cce03f2acba465a33591fbe3
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/db-schema@sha256:ce414d6530ec3f16a3778c4016d2e84681bed34f7d387d29589a9183c55fcb43 docker://$TARGET_PATH/ibm-spectrum-discover/db-schema@sha256:ce414d6530ec3f16a3778c4016d2e84681bed34f7d387d29589a9183c55fcb43
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/db2whrest@sha256:c8e0852809d33413d2a52dedc35966c01a0dc1c71e4fd88306a0b7766811dd18 docker://$TARGET_PATH/ibm-spectrum-discover/db2whrest@sha256:c8e0852809d33413d2a52dedc35966c01a0dc1c71e4fd88306a0b7766811dd18
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/import-tags-app@sha256:5a59884008e59a6dfd6e02c6abe99e144eb6564daf5818708dbe7d356093668e docker://$TARGET_PATH/ibm-spectrum-discover/import-tags-app@sha256:5a59884008e59a6dfd6e02c6abe99e144eb6564daf5818708dbe7d356093668e
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/keystone@sha256:13aeaa84391227d5a1eff6bb416f743a0311776ffab53e71863adc627dc8f37c docker://$TARGET_PATH/ibm-spectrum-discover/keystone@sha256:13aeaa84391227d5a1eff6bb416f743a0311776ffab53e71863adc627dc8f37c
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/policyengine@sha256:6b16017d7949ba59896728edddaf9a109288633a9fd616212995733c274ce655 docker://$TARGET_PATH/ibm-spectrum-discover/policyengine@sha256:6b16017d7949ba59896728edddaf9a109288633a9fd616212995733c274ce655
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/moproducer@sha256:bd2a2ba826050597f9311b89af85380fd4324c24f7e6080a484af70b2c4f2666 docker://$TARGET_PATH/ibm-spectrum-discover/moproducer@sha256:bd2a2ba826050597f9311b89af85380fd4324c24f7e6080a484af70b2c4f2666
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/reports@sha256:ca1cdbcedc9655d9c741d86ad9071f26d33595d7955d1430b9a3825477e7c3b2 docker://$TARGET_PATH/ibm-spectrum-discover/reports@sha256:ca1cdbcedc9655d9c741d86ad9071f26d33595d7955d1430b9a3825477e7c3b2
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/sdmonitor@sha256:d3e9330ac505bd634991d8f0c1b0a68636cb72e8c004b3ed0a623d09babd4193 docker://$TARGET_PATH/ibm-spectrum-discover/sdmonitor@sha256:d3e9330ac505bd634991d8f0c1b0a68636cb72e8c004b3ed0a623d09babd4193
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/tikaserver@sha256:e098b1dc4a4c42f406238bc1bb63843c5e162556a92f270150e80e9de1fe04bd docker://$TARGET_PATH/ibm-spectrum-discover/tikaserver@sha256:e098b1dc4a4c42f406238bc1bb63843c5e162556a92f270150e80e9de1fe04bd
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/uifrontend@sha256:b9efa7e0932113d39b8576d51150af0ee2fdeaed47ea1ac9faa66a388f803891 docker://$TARGET_PATH/ibm-spectrum-discover/uifrontend@sha256:b9efa7e0932113d39b8576d51150af0ee2fdeaed47ea1ac9faa66a388f803891
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/uibackend@sha256:47c7d6b5e884a60a95cc3dc4511e89b689ebb0fad03f2da7b56fae3f702dfa63 docker://$TARGET_PATH/ibm-spectrum-discover/uibackend@sha256:47c7d6b5e884a60a95cc3dc4511e89b689ebb0fad03f2da7b56fae3f702dfa63
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/wkc-connector@sha256:460dfd8e06242278246e55ff8241ad8af5ea8f747e86b5b6f283874c18bbc75a docker://$TARGET_PATH/ibm-spectrum-discover/wkc-connector@sha256:460dfd8e06242278246e55ff8241ad8af5ea8f747e86b5b6f283874c18bbc75a
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/scaleafmdatamover@sha256:d485870db5d654b1eb403420fc772ab8a2e14ac8ed71607123df5e5a35fa274b docker://$TARGET_PATH/ibm-spectrum-discover/scaleafmdatamover@sha256:d485870db5d654b1eb403420fc772ab8a2e14ac8ed71607123df5e5a35fa274b
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/scaleilmdatamover@sha256:cbf362fb09c977591dd92c7671a8fa16467d8026cdf7d63695fa2ebb7cb005b5 docker://$TARGET_PATH/ibm-spectrum-discover/scaleilmdatamover@sha256:cbf362fb09c977591dd92c7671a8fa16467d8026cdf7d63695fa2ebb7cb005b5
skopeo copy --all docker://cp.icr.io/cp/ibm-spectrum-discover/isd-proxy@sha256:b27811ad3549001f9d2caa05526b42fd2f9aa9ef62d22d1f9a627331a99a916e docker://$TARGET_PATH/ibm-spectrum-discover/isd-proxy@sha256:b27811ad3549001f9d2caa05526b42fd2f9aa9ef62d22d1f9a627331a99a916e
skopeo copy --all docker://icr.io/cpopen/ibm-spectrum-discover-operator@sha256:08b1530d286dae67238288e6b179874bec1653643b1fa674a4be0519b63e2af4 docker://$TARGET_PATH/ibm-spectrum-discover-operator@sha256:08b1530d286dae67238288e6b179874bec1653643b1fa674a4be0519b63e2af4
skopeo copy --all docker://icr.io/cpopen/ibm-spectrum-discover-operator-bundle@sha256:78e7c3739c6c7d027df82d842acb1b12fb190155d2f96359138fa2c405be221b docker://$TARGET_PATH/ibm-spectrum-discover-operator-bundle@sha256:78e7c3739c6c7d027df82d842acb1b12fb190155d2f96359138fa2c405be221b
skopeo copy --all docker://icr.io/cpopen/ibm-spectrum-discover-operator-catalog@sha256:d57053f13aa687fdd30e6858a31645ff8e80c3f03e02cf1ad2d42432b465e80f docker://$TARGET_PATH/ibm-spectrum-discover-operator-catalog@sha256:d57053f13aa687fdd30e6858a31645ff8e80c3f03e02cf1ad2d42432b465e80f

cat << EOF > catalog-source-datacataloging.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-operators-data-cataloging
  namespace: openshift-marketplace
spec:
  displayName: Red Hat Operators for Data Cataloging
  image: "$TARGET_PATH/data-cataloging-redhat-operator-index:v4.10"
  sourceType: grpc
EOF
oc apply -f catalog-source-datacataloging.yaml

cat << EOF > catalog-source-ibm.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Operator Catalog
  image: "$TARGET_PATH/ibm-operator-catalog@sha256:056db327f51ccc094e72f56d24ed0fc0c333369c33e80624f2bdccf7ca813435"
  sourceType: grpc
EOF
oc apply -f catalog-source-ibm.yaml

cat << EOF > imagecontentpolicy-datacataloging.yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  labels:
    operators.openshift.org/catalog: "true"
  name: isd-mirror
spec:
  repositoryDigestMirrors:
  - mirrors:
    - $TARGET_PATH
    source: icr.io/cpopen
  - mirrors:
    - $TARGET_PATH
    source: registry.redhat.io/redhat
  - mirrors:
    - $TARGET_PATH/amq
    - $TARGET_PATH
    source: registry.redhat.io/amq7
  - mirrors:
    - $TARGET_PATH/ibm-spectrum-discover
    source: cp.icr.io/cp/ibm-spectrum-discover
  - mirrors:
    - $TARGET_PATH/db2u
    source: icr.io/db2u
EOF
oc apply -f imagecontentpolicy-datacataloging.yaml
