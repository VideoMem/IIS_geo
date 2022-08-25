# IIS_GEO

Geolocalización, clasificación, reporte de carga por servicio y alerta de accesos por ONB

### Motivación

Nuestro caso de uso tiene un portal u app de atención/self-service al cliente, el mismo genera
metadatos como puede ser, la geolocalización directa y/o la IP con la que el cliente realizó la conexión al servicio.

Esa IP se puede utilizar para geolocalizar al cliente de forma aproximada.
En algunos casos, dependiendo del origen, esos datos de geolocalización pueden ser más precisos.

La información de geolocalización tiene mucho potencial para el análisis de fraude y
la generación de campañas de marketing dirigidas.

Por ejemplo, si detectaramos que el mismo cliente accede el mismo día desde dos países diferentes,
y el tiempo entre accesos sugiere que el movimiento físico del mismo no es posible
(de Argentina a Colombia en menos de 2 horas). Nuestro sistema puede generar una alerta 
por comportamiento irregular.

En el segundo caso, se podría analizar cual es la 'zona promedio' de estadía del cliente y detectar cuando 
el mismo sale de la misma.
Con esto se podría generar un indicador de que el cliente está de viaje y de esta forma ofrecerles productos 
relacionados al turismo.

### Alcance

El presente proyecto se limitará a la explotación del primero de los casos de geolocalización (comportamiento irregular),
generando el reporte de ubicaciones en conflicto espacio-temporal.
También proveerá del informe de hits por servicio, canal y segmento permitiendo un análisis detallado de la carga que 
tienen los mismos, y de esta forma asistir en el diseño/ampliación de la capacidad de infraestructura a futuro.

**Para ello debe resolver los siguientes hitos:**  

- Enriquecer los datos crudos de origen (Kafka) en NiFi con la información de geolocalización para el caso en que origen no la informe.  
- Disponibilizar el resultado enriquecido en otro topic/broker de Kafka.  
- Consumir desde el topic enriquecido los mensajes y disponibilizarlos como tabla externa en HDFS en formato parquet.  
- Generar los scripts para el procesamiento por lotes de la información de la tabla externa a las finales.  
- Obfuscar la información del cliente y del servicio de forma que se pueda compartir las visualizaciones sin exponer datos personales o sensibles en tableros (semi) públicos.  
- Proporcionar las vistas de explotación del tablero.  
- Generar los tableros de visualización en PowerBI.  

### Arquitectura

El proyecto tiene dos partes principales, una es online, y la otra es batch.  
En la parte online, se reciben los datos de origen, se enriquecen y se almacenan en HDFS en formato parquet.  
Una vez ahí, la consolidación, obfuscación y el análisis se hacen en batch.  

En una segunda etapa se podría refactorizar para que sea completamente online.  

#### Stack tecnológico utilizado:  
- Kafka  
- NiFi  
- APIs de geolocalización  
- Spark Streams  
- Hadoop (Hive e Impala)  
- PowerBI  

#### Online:

La cadena online empieza leyendo en NiFi desde un tópico de Kafka origen.  
En NiFi se realizan las consultas a la API de geolocalización por IP en el caso de que los datos de geolocalización no estén disponibles.  
A cada par de coordenadas (latitud y longitud) se le asigna un valor de accuracy (precisión).  
Cuanto más grande es el puntaje de accuracy mayor es la precisión en la geolocalización.  

Los resultados enriquecidos se publican en otro topic y broker de Kafka para consumirse luego esde Spark a HDFS en el DW.  

![diagrama de ingesta](docs/GEO_first_version.svg)

El schema/formato del mensaje enriquecido es el siguiente:

```json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {
    "timestamp": {
      "type": "string"
    },
    "latitud": {
      "type": "string"
    },
    "longitud": {
      "type": "string"
    },
    "country": {
      "type": "string"
    },
    "dt": {
      "type": "integer"
    },
    "documentnbr": {
      "type": "string"
    },
    "documenttype": {
      "type": "string"
    },
    "accuracy": {
      "type": "string"
    },
    "segmento": {
      "type": "string"
    },
    "servicio": {
      "type": "string"
    },
    "level": {
      "type": "string"
    }
  },
  "required": [
    "timestamp",
    "latitud",
    "longitud",
    "country",
    "dt",
    "documentnbr",
    "documenttype",
    "accuracy",
    "segmento",
    "servicio",
    "level"
  ]
}
```
**timestamp**: la marca de tiempo del acceso en formato ISO

**latitud**: Latitud de geolocalización en formato decimal

**longitud**: Longitud de geolocalización en formato decimal

**country**: País

**dt**: Auxiliar de particionado, formato YYYYMMdd

**documentnbr**: Número de documento

**documenttype**: Tipo de documento

**accuracy**: Precisión de geolocalización

**segmento**: Segmentos a los que pertenece el cliente separados por comas

**servicio**: Endpoint/servicio en donde se realizó el acceso.

**level**: INFO o DEBUG dependiendo del origen del dato.

#### Batch:

Los datos enriquecidos se disponibilizan en una tabla externa que puede consultarse desde Hive.

Una vez allí, se extraen los datos finales para la tabla de hechos, en nuestro caso el registro de cada 
acceso con su geolocalización, por cliente, servicio y segmento.

También se crean tres tablas de dimensiones asociadas a los hechos.  
- Clientes  
- Servicios  
- Segmentos  

Por cada cliente se genera un único client_id, lo mismo por cada servicio,
hay un service_id que es único para cada endpoint.

Tanto client_id como service_id son claves y no poseen datos que relacionen al cliente o al servicio en la tabla de hechos de forma directa.  
De esta forma, se podrían disponibilizar datos de los hechos sin exponer los datos personales del cliente o los detalles del servicio al que accedió.  
Para obtener el dato sensible, se debe hacer el inner join con la tabla de dimensiones correspondiente.  

## Modelo lógico relacional de datos

Ver [detalles del modelo de datos](docs/modelo_relacional.md)
















