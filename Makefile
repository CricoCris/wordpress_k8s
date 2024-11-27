
# Nome da aplicação e namespace(IMPORTANTE!!!!)
APP_NAME=tanodescontinho
NAMESPACE=tanodescontinho

#Se for testar como homologação primeiro(totalmente recomendado) true or false apenas. Cuidado com espaços! Habilitar teste servidor(true)
ENABLE_HML=false

#Dados da infra(podem ser alteradas sem aviso prévio...)
DNS_EC2_1=ec2-52-67-172-113.sa-east-1.compute.amazonaws.com
DNS_EC2_2=ec2-15-228-22-207.sa-east-1.compute.amazonaws.com
KEYDIR="~/.ssh/id_rsa"

#wordpress
LABELWP=app=wordpress-$(NAMESPACE)
CONTENT_NAME=tanodescontinho.tar.gz
CONTENT_CRAWLER_NAME=crawlers_descontador.tar.gz
CONTENT_DIR=../vagalume_dados/

#ftp([USER]:[PASS][PERFIL]) Porta 22022 ate 22032 (22022 tabaratasso - 22023 avisadesconto - 22024 tanodescontinho)
FTP_CREDENCIALS=sftp:T@c0m120:33
FTP_PORT=22028

#bancode dados
#Obs: O de prefência não usar "#" na senha. Se for necessário colocar "" antes do caractere(o "" não fara parte da senha. Ex: ABC123#$% --> a senha seria ABC123#$% ).
MYSQL_ROOT_PASSWORD="T@c0m@1020!"
MYSQL_DATABASE="tanodescontinho"
MYSQL_USER="tanodescontinho"
MYSQL_PASSWORD="T@c0m@1020"
MYSQL_TCP_PORT=59008# NAO INSERIR ASPAS NEM DEIXAR ESPAÇOS ANTES DO COMENTARIO!!!!
DB_PRINCIPAL_FILE=tanodescontinho_wp.sql
DB_SHORT_FILE=short_generic.sql



####################################################
###### NÃO ALTERAR DESSA REGIÃO PARA BAIXO!!! ######
####################################################

PODWP=$(shell kubectl get pods -n $(NAMESPACE) -l $(LABELWP) -o jsonpath='{.items[0].metadata.name}' | awk '{$$1=$$1; print}')
CONFIGMAP_FILE=./data/configmap_ingress.yaml
SVC_FILE=./data/svc_ingress.yaml


# Variável para o novo valor de porta para o ingress ftp
NEW_ENTRY_SFTP=\"$(FTP_PORT)\": $(NAMESPACE)/sftp-service-$(NAMESPACE):22
NEW_APP_SFTP_PROTOCOL := "sftp"
NEW_PORT_SFTP_NAME := "sftp-$(NAMESPACE)"
NEW_PORT_SFTP := $(FTP_PORT)
NEW_TARGET_SFTP_PORT := $(FTP_PORT)

# Variável para o novo valor de porta para o ingress mysql
NEW_ENTRY_MYSQL=\"$(MYSQL_TCP_PORT)\": $(NAMESPACE)/mysql-service-$(NAMESPACE):$(MYSQL_TCP_PORT)
NEW_APP_MYSQL_PROTOCOL := "mysql"
NEW_PORT_MYSQL_NAME := "mysql-$(NAMESPACE)"
NEW_PORT_MYSQL := $(MYSQL_TCP_PORT)
NEW_TARGET_MYSQL_PORT := $(MYSQL_TCP_PORT)

# Converter valores para secrets base64
BASE64_MYSQL_ROOT_PASSWORD=$(shell echo -n $(MYSQL_ROOT_PASSWORD) | base64)
BASE64_MYSQL_DATABASE=$(shell echo -n $(MYSQL_DATABASE) | base64)
BASE64_MYSQL_USER=$(shell echo -n $(MYSQL_USER) | base64)
BASE64_MYSQL_PASSWORD=$(shell echo -n $(MYSQL_PASSWORD) | base64)
BASE64_MYSQL_TCP_PORT=$(shell echo -n $(MYSQL_TCP_PORT) | base64)
BASE64_FTP_CREDENCIALS=$(shell echo -n $(FTP_CREDENCIALS) | base64)

update-values:
	@echo "Atualizando arquivo values.yaml com valores base64..."	
	sed -i 's/\(MYSQL_ROOT_PASSWORD: *\).*/\1$(BASE64_MYSQL_ROOT_PASSWORD)/' wordpress-chart/values.yaml
	sed -i 's/\(MYSQL_DATABASE: *\).*/\1$(BASE64_MYSQL_DATABASE)/' wordpress-chart/values.yaml
	sed -i 's/\(MYSQL_USER: *\).*/\1$(BASE64_MYSQL_USER)/' wordpress-chart/values.yaml
	sed -i 's/\(MYSQL_PASSWORD: *\).*/\1$(BASE64_MYSQL_PASSWORD)/' wordpress-chart/values.yaml
	sed -i 's/\(MYSQL_TCP_PORT: *\).*/\1$(BASE64_MYSQL_TCP_PORT)/' wordpress-chart/values.yaml
	sleep 3
	@echo "Atualizando arquivo values.yaml com o namespace $(NAMESPACE)"	
	sed -i '/namespace:/!b;n;s/name:.*/name: $(NAMESPACE)/' wordpress-chart/values.yaml
	sleep 3 
	@echo "Atualizando arquivo values.yaml com valores alfanuméricos..."	
	sed -i '/db:/,/name:/s/\(name: *\).*/\1$(MYSQL_DATABASE)/' wordpress-chart/values.yaml
	sed -i '/db:/,/password:/s/\(password: *\).*/\1$(MYSQL_ROOT_PASSWORD)/' wordpress-chart/values.yaml		
	sed -i '/db:/,/host:/s/\(host: \).*/\1"mysql-service-$(NAMESPACE):$(MYSQL_TCP_PORT)"/' wordpress-chart/values.yaml
	sed -i '/^\(\s*port: \).*/s//\1$(MYSQL_TCP_PORT)/' wordpress-chart/values.yaml
	sleep 3
	@echo "Atualizando arquivo values.yaml com valores de ftp..."	
	sed -i 's/\(sftp-credentials: *\).*/\1$(BASE64_FTP_CREDENCIALS)/' wordpress-chart/templates/secret.yaml
	sleep 3

update-ports:
	@echo "Atualizando arquivo values.yaml com valores de ftp..."	
	sed -i 's/\(sftp-credentials: *\).*/\1$(BASE64_FTP_CREDENCIALS)/' wordpress-chart/templates/secret.yaml
	sleep 3 
	@echo "Adicionando porta ftp ao $(CONFIGMAP_FILE)"		
	sed -i '$$ i\  $(NEW_ENTRY_SFTP)' $(CONFIGMAP_FILE)
	sleep 3
	@echo "Adicionando porta mysql ao $(CONFIGMAP_FILE)"		
	sed -i '$$ i\  $(NEW_ENTRY_MYSQL)' $(CONFIGMAP_FILE)
	sleep 3
	@echo "Adicionando novo appProtocol sftp no  servico ingress..."
	sed -i '/ports:/a\  - appProtocol: $(NEW_APP_SFTP_PROTOCOL)\n    name: $(NEW_PORT_SFTP_NAME)\n    port: $(NEW_PORT_SFTP)\n    protocol: TCP\n    targetPort: $(NEW_TARGET_SFTP_PORT)' $(SVC_FILE)
	sleep 3
	@echo "Adicionando novo appProtocol mysql no  servico ingress..."
	sed -i '/ports:/a\  - appProtocol: $(NEW_APP_MYSQL_PROTOCOL)\n    name: $(NEW_PORT_MYSQL_NAME)\n    port: $(NEW_PORT_MYSQL)\n    protocol: TCP\n    targetPort: $(NEW_TARGET_MYSQL_PORT)' $(SVC_FILE)
	sleep 3

#instalacao completa(único passo)
fullinstall: helmapply copycrawler deploydb 

partinstall: copydataandcrawler

#Aplicando novas portas ao configmap do ingress

update-ingress: update-ports update-configmap-ingress update-svc-ingress

update-configmap-ingress:
	kubectl apply -f $(CONFIGMAP_FILE) -n ingress-nginx

update-svc-ingress:
	kubectl apply -f $(SVC_FILE) -n ingress-nginx

copping: copydataandcrawler deploydb

conditional-target:
	@if [ "$(ENABLE_HML)" = "true" ]; then \
	    sed -i '/hml:/,/enabled:/s/\(enabled: *\).*/\1true/' wordpress-chart/values.yaml; \
	else \
	    sed -i '/hml:/,/enabled:/s/\(enabled: *\).*/\1false/' wordpress-chart/values.yaml; \
	fi

createns: update-values
	kubectl get namespace $(NAMESPACE) || kubectl create ns $(NAMESPACE)
	kubectl config set-context --current --namespace=$(NAMESPACE)


testtemplate: conditional-target createns
	helm template  $(NAMESPACE) ./wordpress-chart -f ./wordpress-chart/values.yaml -n $(NAMESPACE) >result.yaml

helmapply: createns conditional-target
	helm install  $(NAMESPACE) ./wordpress-chart -f ./wordpress-chart/values.yaml -n $(NAMESPACE)

helmupgrade: createns conditional-target
	helm upgrade --install $(NAMESPACE) ./wordpress-chart -f ./wordpress-chart/values.yaml -n $(NAMESPACE)


#copiando o conteudo para dentro do pod.
#Obs: Sefor a primeira vez, usar o "copydatafull". Uma vez extraido, utilizar o "copydata".
copydata: copy-tar descompress-tar

copydataandcrawler:  copy-tar descompress-tar copy-crawlers-tar descompress-crawlers-tar

copycrawler:  copy-crawlers-tar descompress-crawlers-tar

copydatafull: compress-tar copy-tar descompress-tar

#comando para esperar 15 segundos que o wordpress esteja disponível e iniciar a cópia
espera:
	@echo "Aguardando 30 segundos para que o wordpress do pod $(PODWP) esteja disponível e iniciar a cópia..."
	sleep 30

getpod:
	@echo "O nome do pod WordPress é: $(PODWP)"

compress-tar:
	tar -czvf $(CONTENT_DIR)/$(CONTENT_NAME) -C $(CONTENT_DIR) .

compress-crawler-tar:
	tar -czvf $(CONTENT_DIR)/$(CONTENT_CRAWLER_NAME) -C $(CONTENT_DIR)/content .

copy-tar: getpod espera
	@echo "Limpando o diretório do pod $(PODWP)"
	kubectl exec -n $(NAMESPACE) $(PODWP) -- rm -rf /var/www/html/*
	@echo "Copiando arquivos no pod $(PODWP) (pode levar muito tempo...)"
	kubectl cp $(CONTENT_DIR)/$(CONTENT_NAME) $(PODWP):/var/www/html/ -n $(NAMESPACE)

copy-crawlers-tar: getpod espera
	@echo "Copiando arquivos crawler no pod $(PODWP) (pode levar muito tempo...)"
	kubectl cp $(CONTENT_DIR)/$(CONTENT_CRAWLER_NAME) $(PODWP):/crawler -n $(NAMESPACE)

descompress-tar: getpod	
	@echo "Descomprimindo arquivos no pod $(PODWP)"
	kubectl exec -n $(NAMESPACE) $(PODWP) -- tar -xzvf /var/www/html/$(CONTENT_NAME) -C /var/www/html/ && kubectl exec -n $(NAMESPACE) $(PODWP) -- rm /var/www/html/$(CONTENT_NAME)
	@echo "Organizando o diretório wordpress..."
	kubectl cp script.sh $(PODWP):/var/www/html/ -n $(NAMESPACE)
	kubectl exec -n $(NAMESPACE) -i $(PODWP) -- bash -c /var/www/html/script.sh
# 	kubectl exec -n $(NAMESPACE) $(PODWP) -- bash -c  cp -p /var/www/html/htaccessORIGINAL /var/www/html/.htaccess

descompress-crawlers-tar: getpod
	@echo "Extraindo arquivos crawler no pod $(PODWP) (pode levar muito tempo...)"
	kubectl exec -n $(NAMESPACE) $(PODWP) -- tar -xzvf /crawler/$(CONTENT_CRAWLER_NAME) -C /crawler && kubectl exec -n $(NAMESPACE) $(PODWP) -- rm /crawler/$(CONTENT_CRAWLER_NAME)

testemv: getpod
	kubectl cp script.sh $(PODWP):/var/www/html/ -n $(NAMESPACE)
	kubectl exec -n $(NAMESPACE) -i $(PODWP) -- bash -c /var/www/html/script.sh



	

#########################
### Infra-esstrutura ####
#########################

# Caminho para os arquivos YAML do Kubernetes
K8S_DIR=./infra

# Alvo para aplicar as configurações de Kubernetes
deploymetricsServer:
	kubectl apply -f $(K8S_DIR)/metricsServer.yaml	

deployingress:
	kubectl apply -f $(K8S_DIR)/ingress-controler.yaml

deploycertmanager:
	kubectl apply -f $(K8S_DIR)/cert-manager.yaml

deployissuer: deployingress
	kubectl apply -f $(K8S_DIR)/clusterissuer.yaml

deployinfra: deploymetricsServer deployingress deploycertmanager deployissuer

########################


conditional-db:
	@if [ "$(ENABLE_HML)" = "true" ]; then \
		kubectl exec -i mysql-statefullset-$(NAMESPACE)-0 -- mysql --user=root --port=$(MYSQL_TCP_PORT) --password=$(MYSQL_ROOT_PASSWORD) -e "USE $(MYSQL_DATABASE); UPDATE wp_options SET option_value = 'http://hml.$(NAMESPACE).com.br' WHERE option_name = 'siteurl'; UPDATE wp_options SET option_value = 'http://hml.$(NAMESPACE).com.br' WHERE option_name = 'home';"; \
	fi

createdbmainshort:	
	kubectl -n $(NAMESPACE) exec -i mysql-statefullset-$(NAMESPACE)-0 -- mysql --user=root --port=$(MYSQL_TCP_PORT) --password=$(MYSQL_ROOT_PASSWORD) -e "CREATE DATABASE IF NOT EXISTS $(MYSQL_DATABASE);"
	kubectl -n $(NAMESPACE) exec -i mysql-statefullset-$(NAMESPACE)-0 -- mysql --user=root --port=$(MYSQL_TCP_PORT) --password=$(MYSQL_ROOT_PASSWORD) -e "CREATE DATABASE IF NOT EXISTS short;"
dumpdbmain: createdbmainshort
	kubectl -n $(NAMESPACE) exec -i mysql-statefullset-$(NAMESPACE)-0 -- mysql --user=root --port=$(MYSQL_TCP_PORT) --password=$(MYSQL_ROOT_PASSWORD) < $(CONTENT_DIR)/$(DB_PRINCIPAL_FILE)	
dumpdbshort: 
	kubectl -n $(NAMESPACE) exec -i mysql-statefullset-$(NAMESPACE)-0 -- mysql --user=root --port=$(MYSQL_TCP_PORT) --password=$(MYSQL_ROOT_PASSWORD) < $(CONTENT_DIR)/$(DB_SHORT_FILE)

deploydb: espera dumpdbshort



