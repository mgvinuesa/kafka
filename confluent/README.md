# Guia de uso

## Setup inicial
Descargar el contenido del repo, en el se encuentra

- Fichero docker-compose.yml con el stack del entorno
- Carpeta conectores, la cual contiene los distintos conectores de Kafka Connect (en zip). Se referencia como volumen al conector de connect.
- Carpeta scripts_*, para la BD de oracle/sqlserver..., contiene los scripts necesarios para configurar el LOG MINER de la BD

Para poder descargarse la imagen de Oracle, es necesario lo siguiente

- Acceder a: https://container-registry.oracle.com/ (se debe tener una cuenta de oracle)
- Ir a Databases -> enterprise y aceptar los terminos y condiciones (ver imagen)
- Descargarse la imagen previamente, haciendo login en docker registry

```
docker login container-registry.oracle.com
docker pull container-registry.oracle.com/database/enterprise:latest
```
> El pull se puede hacer cuando se levante el compose, pero al estar securizado por probar que todo funciona sin levantar el stack. Revisar si es necesario hacer login en el docker hub.

## Unzip de conectores

```
mkdir connect
unzip ./conectores/confluentinc-kafka-connect-oracle-cdc-1.0.3.zip
mv confluentinc-kafka-connect-oracle-cdc-1.0.3 ./connect/confluentinc-kafka-connect-oracle-cdc

unzip ./conectores/confluentinc-kafka-connect-jdbc-10.7.6.zip
mv confluentinc-kafka-connect-jdbc-10.7.6 ./connect/confluentinc-kafka-connect-jdbc

```


## Levantar el stack

Levantar el stack de docker compose

```
docker compose up -d
```

Los puertos son los siguientes

- ZooKeeper: 2181
- Kafka broker: 9092
- Kafka broker JMX: 9101
- Confluent Schema Registry: 8081
- Kafka Connect: 8083
- Confluent Control Center: 9021
- ksqlDB: 8088
- Confluent REST Proxy: 8082
- Oracle 19c DB: 1521
- SQL Server 2017: 1433


Acceder al Control Center: http://localhost:9021/

El proceso tarda. Revisar los logs mediante los siguientes comandos:

```
docker compose logs -f
docker compose logs <servicename> -f
```

## Configuracion de la BD

Para cambiar la password de admin

```
docker exec oracle ./setPassword.sh <password>
```

Para conectarse como usuario SYS elegir usuario tipo SYSDBA

Ejecutar el setup de la BD de Oracle para activar el CDC (se ha definido un volume con los scripts)

```
docker container exec -it oracle /bin/bash
cd /scripts
sh sqlplus.sh oracle_setup.sql
```
En este punto hemos creado el usuario para el conector identificado como C##myuser y con password = password

```
CREATE USER C##myuser IDENTIFIED BY password CONTAINER=ALL;
```
## Validar que se ha configurado correctamente la BD para el CDC

```
docker container exec -it oracle /bin/bash
cd /scripts
sh sqlplus.sh oracle-readiness.sql C##MYUSER ''
```



## Cargar datos adicionales
Cargar los datos sobre los que trabajaremos en la BD

```
docker container exec -it oracle /bin/bash
cd /scripts
sh sqlplus.sh /scripts/init_data.sql
```

## Creacion del conector sobre todas las tablas del usuario

Se puede hacer desde el control center. Pero mejor usar la API con POSTMAN
La suite de POSTMAN se encuentra en el folder /postman



#Informacion de interes
## Comandos compose
docker-compose up --force-recreate --no-deps connect -d


## Ejecutar comandos en containers

```
docker container exec -it <container> <command>
docker container exec -it <container> /bin/bash
```

## Ver estados (unhealthy) de los containers

```
manu@AT-5CD2144YCB:/mnt/c/Users/mgarcia.devinuesa/OneDrive - knowmad mood/Dev/github/mgvinuesa/kafka/confluent$ docker ps
CONTAINER ID   IMAGE                                                        COMMAND                  CREATED          STATUS                      PORTS                                                                                  NAMES
10255a75362c   container-registry.oracle.com/database/enterprise:19.3.0.0   "/bin/bash -c 'exec …"   22 minutes ago   Up 22 minutes (unhealthy)   0.0.0.0:1521->1521/tcp, :::1521->1521/tcp                                              oracle
4ae142067529   confluentinc/cp-ksqldb-cli:7.5.0                             "/bin/sh"                18 hours ago     Up 18 hours                                                                                                        ksqldb-cli
bb53a05a8b03   confluentinc/ksqldb-examples:7.5.0                           "bash -c 'echo Waiti…"   18 hours ago     Up 18 hours                                                                                                        ksql-datagen
8010318e85f6   confluentinc/cp-enterprise-control-center:7.5.0              "/etc/confluent/dock…"   18 hours ago     Up 18 hours                 0.0.0.0:9021->9021/tcp, :::9021->9021/tcp                                              control-center
d077a18dfde1   confluentinc/cp-ksqldb-server:7.5.0                          "/etc/confluent/dock…"   18 hours ago     Up 18 hours                 0.0.0.0:8088->8088/tcp, :::8088->8088/tcp                                              ksqldb-server
15ebf012a584   confluentinc/cp-kafka-connect:7.5.0                          "/etc/confluent/dock…"   18 hours ago     Up 18 hours (unhealthy)     0.0.0.0:8083->8083/tcp, :::8083->8083/tcp, 9092/tcp                                    connect
3db13f7d1aed   confluentinc/cp-kafka-rest:7.5.0                             "/etc/confluent/dock…"   4 days ago       Up 18 hours                 0.0.0.0:8082->8082/tcp, :::8082->8082/tcp                                              rest-proxy
18f604cbdc73   confluentinc/cp-schema-registry:7.5.0                        "/etc/confluent/dock…"   4 days ago       Up 18 hours                 0.0.0.0:8081->8081/tcp, :::8081->8081/tcp                                              schema-registry
fcf200030ecb   confluentinc/cp-server:7.5.0                                 "/etc/confluent/dock…"   4 days ago       Up 18 hours                 0.0.0.0:9092->9092/tcp, :::9092->9092/tcp, 0.0.0.0:9101->9101/tcp, :::9101->9101/tcp   broker
33ca840387b6   confluentinc/cp-zookeeper:7.5.0                              "/etc/confluent/dock…"   4 days ago       Up 18 hours                 2888/tcp, 0.0.0.0:2181->2181/tcp, :::2181->2181/tcp, 3888/tcp                          zookeeper
```

## Oracle CDC Connector

Be sure to review license at https://www.confluent.io/hub/confluentinc/kafka-connect-oracle-cdc and download the zip file.


## Oracle Database

https://docs.confluent.io/kafka-connectors/oracle-cdc/current/prereqs-validation.html#connect-oracle-cdc-source-prereqs

## Kafka Connect

Ver conectores instalados en el connect:
curl -s -XGET http://localhost:8083/connector-plugins|jq '.[].class'



## Agradecimientos
Basado en parte en este repo: 
https://github.com/saubury/kafka-connect-oracle-cdc/tree/master
https://github.com/sami12rom/kafka-connect-oracle-cdc/blob/main/oracle_script.sql