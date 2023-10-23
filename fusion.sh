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

cat << EOF > catalog-source-fusion.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: isf-catalog
  namespace: openshift-marketplace
spec:
  displayName: ISF Catalog
  image: bastion.privateocp.gbm.net:5000/fusion-mirror/isf-operator-software-catalog:2.6.1
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m0s
EOF

oc apply -f catalog-source-fusion.yaml
