#!/bin/bash

#  menú
show_menu() {
    clear
    echo "###############################################################################################"
    echo "########## Bienvenido al script de ejecucion de instalador de Openshift en Azure (IaaS) #######"
    echo "###############################################################################################"
    echo "1. Instalar mirror registry"
    echo "2. Realizar mirror de instaladores Openshift"
    echo "3. Realizar mirror del catalogo de Redhat "
    echo "4. Ejecutar todo"
    echo "5. Salir"
}

install_mirror () {
#Verificar existencia de pullsecret.txt
echo " Antes de iniciar recuerde descargar su archivo pullsecret en $HOME, guardelo con el nombre pullsecret.txt"
read -p "Cuenta con su archivo en el directorio mencionado? si/no R:/" iniciar


if [ $iniciar != "si" ]; then
  return 1
fi

if [ ! -f "pullsecret.txt" ]; then
  echo "El archivo pullsecret.txt no existe en el directorio actual"
  return 1
fi

# Install paquetes
typeset -l SO="$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)"
if [ $SO == "ubuntu" ]; then
  sudo apt update -y
  sudo apt install apache2-utils -y
  sudo apt install jq -y
  sudo apt install podman -y
elif [ $SO == "rhel" ]; then
  sudo yum repolist -y
  sudo dnf list podman -y
  sudo dnf install -y podman
  sudo dnf install httpd-tools -y
  sudo dnf install -y jq
fi
# Generar Keygen
ssh-keygen -t ed25519 -N ''
# creacion de directorios mirror
export HOME_MIRROR=/home/azureuser/mirror
sudo mkdir -p $HOME_MIRROR/registry/{auth,certs,data}
sudo chown -R azureuser:azureuser $HOME_MIRROR

echo " ingrese el private dns zone de su bastion \n"
read -p "private DNS Zone: " pvdns
echo $pvdns
rightpvdns="$pvdns"
rightHOSTNAME="$HOSTNAME"
# generacion de certificado
cat << EOF > $HOME_MIRROR/registry/certs/cert.conf
[ req ]
default_bits = 2048
default_keyfile = key.pem
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
C = CR
ST = San Jose
L = San Jose
O = GBM
OU = Software
CN = registry

[ v3_req ]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
basicConstraints = CA:TRUE
authorityKeyIdentifier = keyid,issuer

[ alt_names ]
DNS.1 = localhost
DNS.2 = registry
DNS.3 = $rightHOSTNAME
DNS.4 = registry.$rightpvdns
DNS.5 = $rightHOSTNAME.$rightpvdns
IP.1 = 127.0.0.1
EOF
cd $HOME_MIRROR/registry/certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout server.key -x509 -days 3650 -out server.crt -config cert.conf -extensions v3_req
# crear htpasswd
htpasswd -bBc $HOME_MIRROR/registry/auth/htpasswd admin passw0rd
cd $HOME

if [ $SO == "ubuntu" ]; then
  sudo cp $HOME_MIRROR/registry/certs/server.crt /usr/local/share/ca-certificates/server.crt
  sudo update-ca-certificates
elif [ $SO == "red hat enterprise linux server" ]; then
  sudo cp $HOME_MIRROR/registry/certs/server.crt /etc/pki/ca-trust/source/anchors/
  sudo update-ca-trust
fi
podman run --name mirror-registry -p 5000:5000 -v $HOME_MIRROR/registry/data:/var/lib/registry:z -v $HOME_MIRROR/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v $HOME_MIRROR/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.crt -e REGISTRY_HTTP_TLS_KEY=/certs/server.key -d  docker.io/library/registry:2

echo "#### Listado de Containers PODMAN ####\n ################################\n"
podman ps

}

install_mirror_openshift() {
echo 'Instalando mirror openshift....'
cat pullsecret.txt | jq . > pull-secret.json
cat pull-secret.json

podman login --authfile pull-secret.json $HOSTNAME.$pvdns:5000 --username admin --password passw0rd
cp pull-secret.json $XDG_RUNTIME_DIR/containers/auth.json
REG_CREDS=${XDG_RUNTIME_DIR}/containers/auth.json

OCP_RELEASE=4.12.35
LOCAL_REGISTRY=$HOSTNAME.$pvdns:5000
LOCAL_REPOSITORY='ocp4/openshift4'
PRODUCT_REPO='openshift-release-dev'
LOCAL_SECRET_JSON=$HOME/pull-secret.json
RELEASE_NAME="ocp-release"
ARCHITECTURE='x86_64'

# oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE} --dry-run
oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}
oc adm release extract -a ${LOCAL_SECRET_JSON} --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}"
}

install_catalog_redhat() {
echo 'Instalando catalogo Redhat....'
mkdir clustermdm
cp install-config.yaml clustermdm
./openshift-install create cluster --dir=clustermdm --log-level=debug

podman login registry.redhat.io

curl -u admin:passw0rd -k https://localhost:5000/v2/_catalog | jq . | less

export MIRROR_REGISTRY_DNS=bastion.privateocp.gbm.net:5000
export AUTH_FILE=/home/azureuser/pull-secret.json

#oc get catalogsources.operators.coreos.com -n openshift-marketplace --all
#oc delete catalogsources.operators.coreos.com -n openshift-marketplace --all
oc patch operatorhubs/cluster --type merge --patch '{"spec":{"sources":[{"disabled": true,"name": "community-operators"},{"disabled": true,"name": "certified-operators"},{"disabled": true,"name": "redhat-marketplace"},{"disabled": true,"name": "redhat-operators"}]}}'

nohup oc adm catalog mirror registry.redhat.io/redhat/redhat-operator-index:v4.12 ${MIRROR_REGISTRY_DNS}/olm-mirror --registry-config=${AUTH_FILE} --insecure --index-filter-by-os='linux/amd64' & > nohup-mirror-operator.out
}

ejecutar_todo() {
install_mirror

#Vali:xdando que install_mirror se ejecutara correctamente para seguir con la siguiente funcion
if [ $? -ne 0 ]; then
    return
fi

install_catalog_redhat
}


# Función para manejar la opción seleccionada
opciones() {
    case $1 in
        1)
        install_mirror

            ;;
        2)
            install_mirror_openshift

            ;;
        3)
            install_catalog_redhat
            ;;
        4)
            ejecutar_todo
            ;;
        5)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción no válida. Por favor, selecciona una opción válida."
            ;;
    esac
    read -p "Presiona Enter para continuar..."
}

# Ciclo principal del menú
while true; do
    show_menu
    read -p "Selecciona una opción: " option
    opciones $option
done
