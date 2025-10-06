import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';


String _message = '''
# Filtrado de datos

- El filtrado se aplica simultáneamente para cada columna, utilizando lógica AND.

- El filtro de las columnas **`Facility`** y **`Severity`** indica qué valores específicos se deben incluir en la búsqueda. Solo se mostrarán las filas que contengan esos valores exactos en dichas columnas.

- El filtro de las columnas **`Origen`** y **`PID`** utiliza la sintaxis del comando `LIKE` de SQL.  
  - Si se provee un valor sin caracteres comodín (wildcards), automáticamente se interpretará como `%valor%`.  
  - Esto permite buscar coincidencias que contengan el valor dado en cualquier parte del texto.

- El filtro de la columna **`Mensaje`** utiliza la sintaxis del comando `MATCH` de SQL para mejor eficiencia de búsqueda.  
  - Se agrega un asterisco `*` al final del término de búsqueda, lo que indica que el inicio del texto debe coincidir exactamente con el término especificado, seguido por cualquier secuencia de caracteres.  


## Ejemplos


### Filtro en columna `Origen` usando `LIKE`

Buscar registros cuyo `Origen` contenga la palabra **`server`** en cualquier parte:

```sql
Origen LIKE '%server%'
```

Buscar registros cuyo `Origen` empiece con **`db`**:

```sql
Origen LIKE 'db%'
```

### Filtro en columna `PID` usando `LIKE`

Buscar registros cuyo `PID` contenga la cadena **`123`** en cualquier parte:

```sql
PID LIKE '%123%'
```


### Filtro en columna `Mensaje` usando `MATCH`

Buscar mensajes que comienzan exactamente con **`error`** y pueden continuar con cualquier texto:

```sql
MATCH('error*')
```

Buscar mensajes que comienzan con **`warning`**:

```sql
MATCH('warning*')
```
''';

void displayInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Información"),
          content: SizedBox(
            height: 500,
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: MarkdownBody(data: _message, selectable: true,)
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }